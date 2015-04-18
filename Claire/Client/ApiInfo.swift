//
//  ApiInfo.swift
//  Claire
//
//  Created by Yağızhan Güler on 05/04/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import Foundation
import UIKit

public struct ApiInfo : Printable
{
    var maxImageSize : CGFloat?
    var minImageSize : CGFloat?
    var maxBatchSize : Int?
    var embedAllowed : Bool?
    
    //TODO : Reform
    public var description : String {
        return " MaxImageSize : \(self.maxImageSize)" + " , MinImageSize : \(self.minImageSize) " +
            " , MaxBatchSize : \(self.maxBatchSize)" + " , EmbedAllowed : \(self.embedAllowed)"
    }
}