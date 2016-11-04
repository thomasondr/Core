//
//  CacheProtocol.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 11. 04..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
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
