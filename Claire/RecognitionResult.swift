//
//  RecognitionResult.swift
//  Claire
//
//  Created by Yağızhan Güler on 05/04/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import Foundation

public struct RecognitionResult
{
    public typealias Tag = ( className : String , prob : Double )
    
    public var embed : [Double]?
    public var tags : [Tag]?
}