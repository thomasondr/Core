//
//  Cache.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 20..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreData

public struct CacheItem {
    
    public let cacheItemId : String
    public var data : Any
    
    public init(_ id:String, _ newData:Any) {
        cacheItemId = id
        data = newData
    }
    
}

protocol Cache {
    
    mutating func setCacheItem(_ cacheItem : CacheItem) -> Void
    
    func getCacheItem(id : String) -> CacheItem?
    
    mutating func updateCacheItem(_ cacheItem : CacheItem) -> Void
    
    mutating func removeCacheItem(id: String) -> Void
    
    mutating func clear() -> Void
}

public struct MemoryCache : Cache {
    
    private var privateCache : Dictionary<String,Any> = Dictionary()
    
    public init() {
        
    }
    
    public mutating func setCacheItem(_ cacheItem : CacheItem) -> Void {
        
        privateCache[cacheItem.cacheItemId] = cacheItem
    }
    
    public func getCacheItem(id : String) -> CacheItem? {
        
        return privateCache[id] as? CacheItem
    }
    
    public mutating func updateCacheItem(_ cacheItem : CacheItem) -> Void {
        
        removeCacheItem(id: cacheItem.cacheItemId)
        setCacheItem(cacheItem)
    }
    
    public mutating func removeCacheItem(id: String) -> Void {
        
        privateCache.removeValue(forKey: id)
    }
    
    public mutating func clear() -> Void {
        privateCache.removeAll()
    }
}

public struct PersistentCache : Cache {
    
    public init() {
        
    }

    public mutating func setCacheItem(_ cacheItem : CacheItem) -> Void {
        
        CoreDataManager.shareInstance.insertPersistentItem(cacheItem)
        CoreDataManager.shareInstance.save()
    }
    
    public func getCacheItem(id : String) -> CacheItem? {
        
        let persistedObjects = CoreDataManager.shareInstance.fetchById(id)
    
        guard let storedItem : PersistentCacheItem = persistedObjects?.first else {
            return nil
        }
        
        return storedItem.cacheItem()
    }
    
    public mutating func updateCacheItem(_ cacheItem : CacheItem) -> Void {
        
        removeCacheItem(id: cacheItem.cacheItemId)
        setCacheItem(cacheItem)
    }
    
    public mutating func removeCacheItem(id: String) -> Void {
        
        CoreDataManager.shareInstance.deleteById(id)
        CoreDataManager.shareInstance.save()
    }
    
    public mutating func clear() -> Void {
        
        CoreDataManager.shareInstance.clear()
        CoreDataManager.shareInstance.save()
    }
}

fileprivate class PersistentCacheItem: NSManagedObject {
    
    @NSManaged var cacheItemId : String?
    @NSManaged var data : Any?
    
    class func insert(_ cacheItem: CacheItem, into context: NSManagedObjectContext?) {
        
        
        guard let context = context,
        var managedObject = NSEntityDescription.insertNewObject(forEntityName: "PersistentCacheItem", into: context) as? PersistentCacheItem
        else {
            return
        }
        
        managedObject.cacheItemId = cacheItem.cacheItemId
        managedObject.data = NSKeyedArchiver.archivedData(withRootObject: cacheItem.data)
        
        do {
            try context.save()
        } catch let error {
            print(error)
        }
    }
    
    func cacheItem() -> CacheItem {
        let storedData = NSKeyedUnarchiver.unarchiveObject(with: data as! Data)
        return CacheItem(cacheItemId!,storedData)
    }
}

extension PersistentCacheItem {
    @nonobjc class func fetchRequest() -> NSFetchRequest<PersistentCacheItem> {
        return NSFetchRequest<PersistentCacheItem>(entityName: "PersistentCacheItem");
    }
    
    @NSManaged var timeStamp: NSDate?
}

fileprivate class CoreDataManager: NSObject {
    
    static let shareInstance = CoreDataManager(storeFile: "model")!
    
    var privateContext: NSManagedObjectContext
    var managedObjectContext: NSManagedObjectContext
    var didFinishSetup = false
    
    private init?(storeFile : String) {
        
        let documstsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last
        let storeUrl = documstsDir?.appendingPathComponent(storeFile)
        let bundle = Bundle.init(for: type(of:self))
        
        guard let modelUrl = bundle.url(forResource: storeFile, withExtension: "momd"),
            let model = NSManagedObjectModel.init(contentsOf: modelUrl)
        else {
            return nil
        }
        
        managedObjectContext = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        privateContext = NSManagedObjectContext.init(concurrencyType: .privateQueueConcurrencyType)
        privateContext.persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: model)
        managedObjectContext.parent = privateContext

        super.init()
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
                try coordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: storeUrl, options: options)
                weakSelf?.didFinishSetup = true
            } catch let error {
                print(error)
            }
        }
    }
    
    func insertPersistentItem(_ cacheItem: CacheItem) {
        
        PersistentCacheItem.insert(cacheItem, into: managedObjectContext)
    }
    
    func fetchById(_ identifier: String) -> Array<PersistentCacheItem>? {
        
        let fetchRequest: NSFetchRequest<PersistentCacheItem> = PersistentCacheItem.fetchRequest()
        let predicate = NSPredicate.init(format: "cacheItemId == %@", identifier)
        fetchRequest.predicate = predicate
        
        do {
            let result = try managedObjectContext.fetch(fetchRequest)
            return result
        } catch let error {
            print(error)
            return nil
        }
    }
    
    func deleteById(_ identifier: String) -> Void {
        
        guard let results = fetchById(identifier) else {
            return
        }
        for item in results {
            managedObjectContext.delete(item)
        }
    }
    
    func clear() -> Void {
        
        let fetchRequest: NSFetchRequest<PersistentCacheItem> = PersistentCacheItem.fetchRequest()
        
        do {
            let results = try managedObjectContext.fetch(fetchRequest)
            for item in results {
                managedObjectContext.delete(item)
            }
        } catch let error {
            print(error)
        }
    }
    
    func save() -> Void {
        if !privateContext.hasChanges && !managedObjectContext.hasChanges {
            return
        }
        
        managedObjectContext.performAndWait {
            
            do {
                try self.managedObjectContext.save()
                if self.didFinishSetup {
                    self.privateContext.perform({
                        try self.privateContext.save()
                    } as! () -> Void)
                }
            } catch let error {
                print(error)
            }
        }
    }
}

fileprivate class CoreDataFetchManager : NSObject, NSFetchedResultsControllerDelegate{
    
    var managedObjectContext: NSManagedObjectContext? = nil
    var _fetchedResultsController: NSFetchedResultsController<PersistentCacheItem>? = nil
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
         */
        let container = NSPersistentContainer(name: NSStringFromClass(PersistentCacheItem.self))
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
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        let context = persistentContainer.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func insertNewObject(_ cacheItem: CacheItem) {
        let context = self.fetchedResultsController.managedObjectContext
        PersistentCacheItem.insert(cacheItem, into: managedObjectContext)
        
    }
    
    var fetchedResultsController: NSFetchedResultsController<PersistentCacheItem> {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest: NSFetchRequest<PersistentCacheItem> = PersistentCacheItem.fetchRequest()
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "cacheItemId", ascending: false)
        
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

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        
//        self.tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            //            self.tableView.insertSections(IndexSet(integer: sectionIndex), with: .fade)
            break
        case .delete:
            //            self.tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
            break
        default:
            return
        }
    }
    
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
//            tableView.insertRows(at: [newIndexPath!], with: .fade)
            break
        case .delete:
//            tableView.deleteRows(at: [indexPath!], with: .fade)
            break
        case .update:
//            self.configureCell(tableView.cellForRow(at: indexPath!)!, withEvent: anObject as! Event)
            break
        case .move:
//            tableView.moveRow(at: indexPath!, to: newIndexPath!)
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
//        self.tableView.endUpdates()
    }
    
    /*
     // Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed.
     
     func controllerDidChangeContent(controller: NSFetchedResultsController) {
     // In the simplest, most efficient, case, reload the table view.
     self.tableView.reloadData()
     }
     */

}
