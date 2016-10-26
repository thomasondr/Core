//
//  Cache.swift
//  
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 25..
//
//

import Foundation
import CoreValue
import CoreData

public enum Cache {
    
    case Persistent
    case Memory
    
    func create() -> CacheProtocol {
        switch self {
        case Cache.Persistent:
            return PersistentStore.sharedInstance() as! CacheProtocol
        case Cache.Memory:
            return MemoryStore.sharedInstance() as! CacheProtocol
        }
    }
    
    init(_ persistent: Bool) {
        
        if persistent {
            self = Cache.Persistent
        } else {
            self = Cache.Memory
        }
    }
}

protocol CacheProtocol : NSObjectProtocol {
    
    var context: NSManagedObjectContext { get }
    func save() -> Void
    func clean() -> Void
    
}
