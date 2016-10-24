//
//  MemoryStore.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 23..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreData

public class MemoryStore: NSObject {
    
    public static let sharedInstance = MemoryStore(storeFile: "model")!
    
    public var context: NSManagedObjectContext
    
    private init?(storeFile : String) {
        
        
        guard let modelUrl = Bundle.main.url(forResource: storeFile, withExtension: "momd"),
            let model = NSManagedObjectModel.init(contentsOf: modelUrl)
            else {
                return nil
        }
        
        context = NSManagedObjectContext.init(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = NSPersistentStoreCoordinator.init(managedObjectModel: model)
        
        super.init()
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
}
