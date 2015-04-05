//
//  JSONHelper.swift
//  Claire
//
//  Created by Yağızhan Güler on 05/04/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import Foundation

public class JSONHelper
{

    public typealias JSONDictionary = [String:AnyObject]
    
    class func decodeJSON(data: NSData) -> JSONDictionary? {
        return NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.allZeros, error: nil) as? [String:AnyObject]
    }
    
    class func encodeJSON(dict: JSONDictionary) -> NSData? {
        return dict.count > 0 ? NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions.allZeros, error: nil) : nil
    }
}