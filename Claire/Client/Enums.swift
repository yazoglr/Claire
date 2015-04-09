//
//  Enums.swift
//  Claire
//
//  Created by Yağızhan Güler on 06/04/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import Foundation


public enum Operation : Printable {
    case Embed , Tag , TagAndEmbed
    
    public var description : String { return self.toString() }
    
    private func toString() -> String {
        switch(self){
        case .Embed : return "embed"
        case .Tag : return "tag"
        default : return "tag,embed"
        }
    }
}

//Inspired by Chris Eidhof
//TODO : Adapt the enum to make it more explicative , possibly conforming to Printable protocol
public enum FailReason {
    case CouldNotGetToken
    case CouldNotParseData
    case CouldNotParseJSON
    case NoData
    case NoSuccessStatusCode(statusCode: Int)
    case ReachedMaxNumberOfCalls
    case ApiThrottled
    case Other(NSError)
    
}
