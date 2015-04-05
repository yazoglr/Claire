//
//  ViewController.swift
//  Claire
//
//  Created by Yağızhan Güler on 15/02/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let clientID = "P0tbQmf7axVK7gbrPmpjFKkwsj4BTolZmIaAnOKr"
        let clientSecret = "XxhusB12PKEFqVogSHrtgaCpbQ9pDaowJUqHp6bE"
        let c = ClarifaiApi(appID: clientID , appSecret: clientSecret)
        
        let img = UIImage(named: "metro-north.jpg")!
        
        c.recognizeMedia(Operation.TagAndEmbed, media: [("metro",img)] ,
            success: { (rec : [RecognitionResult] ) -> Void in
                for item in rec {
                    println(item.tags?[5])
                }
            },failure: { (r : Reason , d : NSData?) -> Void in println("Fail") })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

