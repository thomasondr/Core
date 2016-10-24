//
//  PersistentCache.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 22..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreData

class PersistentCacheItem: NSManagedObject {
    
    @NSManaged var cacheItemId : String?
    @NSManaged var data : Any?
    
    init?(_ cacheItem: CacheItem, insertInto context: NSManagedObjectContext?) {
        
        guard let context = context,
            
            let entity = NSEntityDescription.entity(forEntityName: "PersistentCacheItem", in: context) else {
                return nil
        }
        
        super.init(entity: entity, insertInto: context)
        
        cacheItemId = cacheItem.cacheItemId
        data = NSKeyedArchiver.archivedData(withRootObject: cacheItem.data.encode())
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

class CoreDataManager: NSObject {
    
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
        
        _ = PersistentCacheItem(cacheItem, insertInto: managedObjectContext)
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
