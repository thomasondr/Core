//
//  CacheService.swift
//  CoreUser
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 20..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreValue
import CoreData

public struct CacheItem : CVManagedPersistentStruct {
    
    /*
     Operator	Description
     <^>	Map the following operations (i.e. combine map operations)
     <|     Unbox a normal value (i.e. var shop: Shop)
     <||	Unbox a set/list of values (i.e. var shops: [Shops])
     <|?	Unbox an optional value (i.e. var shop: Shop?)
     */
    
    public static let EntityName = "CacheItem"
    
    public var objectID: NSManagedObjectID?
    
    public var data : Data
    
    public static func fromObject(_ o: NSManagedObject) throws -> CacheItem {
        return try curry(self.init)
            <^> o <|? "objectID"
            <^> o <|  "data"
    }
}

public struct CacheService {
    
    public init(withPersistence : Bool){
        
        store = Cache(withPersistence).create()
        let store2 = Cache(withPersistence).create()
        
        assert(store === store2)
    }
    
    let store : CacheProtocol
    
    public func fetchItems() -> Array<CacheItem>? {
        
        do {
            let items: [CacheItem] = try CacheItem.query(store.context, predicate: nil)
            return items
        } catch let error {
            print(error.localizedDescription)
            store.clean()
        }
        return nil
    }
    
    public mutating func makeNew(_ data: Data) -> CacheItem? {
        
        let item = CacheItem(objectID: nil, data:data)

        do {
            _ = try item.toObject(store.context)
                
        } catch CVManagedStructError.structConversionError(let msg) {
            print(msg)
        } catch CVManagedStructError.structValueError(let msg) {
            print(msg)
        } catch let e {
            print(e)            
        }
        
        store.save()
        
        return item
    }
    
    public func save() -> Void {
        store.save()
    }
    
}
