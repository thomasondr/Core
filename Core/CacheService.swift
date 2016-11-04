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
    
    public func fetchItems() throws -> Array<CacheItem> {
        
        do {
            let items: [CacheItem] = try CacheItem.query(store.context, predicate: nil)        
            return items
        } catch let error {
            print(error.localizedDescription)
            throw error
        }
    }
    
    public mutating func create(_ data: Data) throws -> CacheItem {
        
        let item = CacheItem(objectID:nil, data: data)

        do {
            _ = try item.toObject(store.context)
                
        } catch CVManagedStructError.structConversionError(let msg) {
            print(msg)
        } catch CVManagedStructError.structValueError(let msg) {
            print(msg)
        } catch let error {
            print(error.localizedDescription)
            throw error
        }
        
        store.save()
        
        return item
    }
    
    public func save() -> Void {
        store.save()
    }
    
    public func delete(_ cacheItem: CacheItem) throws -> Void {
        
        guard let objectID = cacheItem.objectID else {
            
            print("Item missing objectID. Was it stored before?")
            return
        }
        
        do {
            let object = try store.context.existingObject(with: objectID)
            store.context.delete(object)
            save()
        } catch let err {
            print(err.localizedDescription)
            throw err
        }
    }
    
}
