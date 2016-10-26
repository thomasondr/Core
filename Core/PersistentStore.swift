//
//  CoreValuePersistence.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 22..
//  Copyright © 2016. mkerekes. All rights reserved.
//


import Foundation
import CoreData
import CoreValue

/// Documentation on how to extend nanaged structs, visit https://github.com/terhechte/corevalue
private var global : Any? = nil

class PersistentStore: NSObject, CacheProtocol {
    
    class func sharedInstance( ) -> PersistentStore {
        
        guard let instance = global else {
            global = PersistentStore(storeFile: "model")!
            return global as! PersistentStore
        }
        
        return instance as! PersistentStore
    }
    
    var privateContext: NSManagedObjectContext
    public var context: NSManagedObjectContext
    var didFinishSetup = false
    var storeUrl: URL
    
    private init?(storeFile : String) {
        
        let documstsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        
        guard let modelUrl = Bundle.main.url(forResource: storeFile, withExtension: "momd"),
            let aStoreUrl = documstsDir?.appendingPathComponent(storeFile),
            let model = NSManagedObjectModel.init(contentsOf: modelUrl)
            else {
                return nil
        }
        storeUrl = aStoreUrl
        context = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        privateContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
        privateContext.persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: model)
        context.parent = privateContext
        
        super.init()
        
        initialize()
    }
    
    func initialize() {
        
        weak var weakSelf = self
        
        DispatchQueue.global().async {
            
            let coordinator = weakSelf?.privateContext.persistentStoreCoordinator
            var options : Dictionary<AnyHashable,Any> = Dictionary()
            options[NSMigratePersistentStoresAutomaticallyOption] = true
            options[NSInferMappingModelAutomaticallyOption] = true
            var pragmas : Dictionary<AnyHashable,Any> = Dictionary()
            pragmas["journal_mode"] = "DELETE"
            options[NSSQLitePragmasOption] = pragmas
            do {
                try coordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: weakSelf?.storeUrl, options: options)
                weakSelf?.didFinishSetup = true
            } catch let error {
                print(error)
            }
        }
    }
    
    func save() -> Void {
        if !privateContext.hasChanges && !context.hasChanges {
            return
        }
        
        context.performAndWait {
            
            do {
                try self.context.save()
                if self.didFinishSetup {
                    self.privateContext.perform {
                     
                        do {
                            try self.privateContext.save()
                        } catch let error {
                            print(error)
                        }
                    }
                }
            } catch let error {
                print(error)
            }
        }
    }
    
    func clean() -> Void {
        
        DispatchQueue.global().async {
            
            guard let coordinator = self.privateContext.persistentStoreCoordinator,
                let store = coordinator.persistentStores.first else { return }
            do {
                try coordinator.remove(store)
                
            } catch let error {
                print(error.localizedDescription)
            }
            self.initialize()
        }
    }
    
    /*
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: "model")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                
                /*
                 Typical reasons for an error here include:
                 * The parent directory does not exist, cannot be created, or disallows writing.
                 * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                 * The device is out of space.
                 * The store could not be migrated to the current model version.
                 Check the error message to determine what the actual problem was.
                 */
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        return container
    }()
    
    // MARK: - Fetched results controller
    var fetchedResultsController: NSFetchedResultsController<NSManagedObject> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<NSManagedObject> = NSFetchRequest.init(entityName: CacheItem.EntityName)
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "date", ascending: false)
        
        fetchRequest.sortDescriptors = [sortDescriptor]
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext!, sectionNameKeyPath: nil, cacheName: "Master")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
        do {
            try _fetchedResultsController!.performFetch()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            let nserror = error as NSError
            fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
        }
        
        return _fetchedResultsController!
    }
    var _fetchedResultsController: NSFetchedResultsController<NSManagedObject>? = nil
    
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
        case .delete:
            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        default:
            return
        }
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .fade)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
            //            case .update:
        //                self.configureCell(tableView.cellForRow(at: indexPath!)!, withCacheItem: anObject as! CacheItem)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        default: break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.endUpdates()
    }
    
    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
     // In the simplest, most efficient, case, reload the table view.
     self.tableView.reloadData()
     }
     */
 */
    
}
