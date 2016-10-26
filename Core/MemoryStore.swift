//
//  MemoryStore.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 23..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreData

private var global : Any? = nil

class MemoryStore: NSObject, CacheProtocol {
    
    
    class func sharedInstance( ) -> MemoryStore {
        
        guard let instance = global else {
            global = MemoryStore(storeFile: "model")!
            return global as! MemoryStore
        }
        
        return instance as! MemoryStore
    }
    
    var context: NSManagedObjectContext
    
    private init?(storeFile : String) {
        
        
        guard let modelUrl = Bundle.main.url(forResource: storeFile, withExtension: "momd"),
            let model = NSManagedObjectModel.init(contentsOf: modelUrl)
            else {
                return nil
        }
        
        context = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: model)
        
        super.init()
        
        initialize()
    }
    
    func initialize() -> Void {
        weak var weakSelf = self
        
        DispatchQueue.global().async {
            
            let coordinator = weakSelf?.context.persistentStoreCoordinator
            do {
                try coordinator?.addPersistentStore(ofType: NSInMemoryStoreType, configurationName: nil, at: nil, options: nil)
            } catch let error {
                print(error)
            }
        }
    }
    
    public func save() -> Void {
        if !context.hasChanges {
            return
        }
        
        context.performAndWait {
            
            do {
                try self.context.save()
            } catch let error {
                print(error)
            }
        }
    }
    
    public func clean() -> Void {
        
        DispatchQueue.global().async {
            
            guard let coordinator = self.context.persistentStoreCoordinator,
                let store = coordinator.persistentStores.first else { return }
            do {
                try coordinator.remove(store)
                
            } catch let error {
                print(error.localizedDescription)
            }
            self.initialize()
        }
    }
}
