//
//  CacheItem.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 11. 04..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation
import CoreData
import CoreValue

public typealias JSONDict = Dictionary<String,Any>

public protocol Cacheable {
    
    var cacheItem : CacheItem? { get set }
    
    static var persistObjects : Bool { get set }
    
    func encode() -> JSONDict
    
    mutating func decode(dict : JSONDict)
    
    init()
}

public extension Cacheable {
    
    public init?(fromCacheItem: CacheItem) {
        
        self.init()
        cacheItem = fromCacheItem
        guard let safeCacheItem = cacheItem else {
            return nil
        }
        let jsonDict = NSKeyedUnarchiver.unarchiveObject(with: safeCacheItem.data)
        decode(dict: jsonDict as! JSONDict)
    }
    
    public mutating func saveToCache() -> Void {
        let json = self.encode()
        let data = NSKeyedArchiver.archivedData(withRootObject: json)
        var service = CacheService(withPersistence: Self.persistObjects)
        do {
            self.cacheItem = try service.create(data)
        } catch let err {
            print(err)
        }
    }
    
    static func fetchItems() throws -> [Cacheable] {
        
        let service = CacheService(withPersistence: Self.persistObjects)
        
        do {
            let fetchResults : Array<CacheItem> = try service.fetchItems()
            let cacheable = fetchResults.flatMap({ (cacheItem) -> Cacheable? in
                
                let userData = self.init(fromCacheItem: cacheItem)
                return userData
            })
            
            return cacheable
        } catch let error {
            print(error.localizedDescription)
            throw error
        }
    }
    
    public func delete() throws -> Void {
        
        guard let safeCacheItem = cacheItem else {
            print("Item wasn't saved before")
            return
        }
        let service = CacheService(withPersistence: Self.persistObjects)
        
        do {
            try service.delete(safeCacheItem)
        } catch let error {
            print(error.localizedDescription)
            throw error
        }
    }        
}
