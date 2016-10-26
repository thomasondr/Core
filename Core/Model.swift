//
//  Mode.swift
//  Core
//
//  Created by Kerekes Jozsef-Marton on 2016. 10. 22..
//  Copyright © 2016. mkerekes. All rights reserved.
//

import Foundation

public typealias JSONDict = Dictionary<String,Any>

public protocol Model {}

public protocol CacheStoreable {
    
    func encode() -> JSONDict
    
    func decode(dict : JSONDict) -> Model
}

public enum JSON {
    
    case Model(CacheStoreable,JSONDict)
    case Error(Error)
    
    func parse() throws -> Model {
        switch self {
        case JSON.Model(let model, let json): return model.decode(dict: json)
        case JSON.Error(let error): return ErrorModel(error)
        }
    }
    
    init(_ model: CacheStoreable, withData: Any?) {
        
        switch withData {
        case is JSONDict:
            self = JSON.Model(model, withData as! JSONDict)
        default:
            self = JSON.Error((withData as? Error)!)
        }
    }
}

public struct ErrorModel : Model {
    
    var error : Error? = nil
    
    init(_ error : Error) {
        self.error = error
    }
}
