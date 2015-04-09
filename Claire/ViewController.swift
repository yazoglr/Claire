//
//  ViewController.swift
//  Claire
//
//  Created by Yağızhan Güler on 15/02/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    private var api : ClarifaiApi?
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // A simple example
        let clientID = "P0tbQmf7axVK7gbrPmpjFKkwsj4BTolZmIaAnOKr"
        let clientSecret = "XxhusB12PKEFqVogSHrtgaCpbQ9pDaowJUqHp6bE"
        api = ClarifaiApi(appID: clientID , appSecret: clientSecret)
        
        // A dummy failure handler maker that would generate simple handler functions that print specified messages
        let failHandlerMaker : (String -> ClarifaiApi.FailureHandler) = { message in
            let failHandler : ClarifaiApi.FailureHandler = { reason , data in println("Failure with message \(message)") }
            return failHandler
        }
        
        // A simple info request
        api?.getInfo( { info -> Void in
            //Operation is successful , we are simply printing the info
            println("Printing API info")
            println(info)
            }, failure: failHandlerMaker("Failure while getting info."))
        
        // The following examples are basically recognition requests
        // So , a common success handler that would use the results of these requests is defined
        // What following function does is simply printing the tags in the result should they exist
        let recognitionHandler : ([RecognitionResult] -> Void) = { recogs in
            println("Printing tags")
            for item in recogs {
                item.tags?.map{( t: RecognitionResult.Tag) -> Void  in
                    println(t)
                }
            }
            println("Done printing tags")
        }
        
        
        //Recognizing images from urls
        // A note on the first parameters used in the following functions
        // The first parameter is of type Operation which is an enum with possible values Tag,Embed,TagAndEmbed
        // It simply used as a declaration of operations that are to be done on the images
        api?.recognizeURLs(.TagAndEmbed, urls: ["http://www.clarifai.com/static/img_ours/autotag_examples/coffee.jpg"], success: recognitionHandler, failure: failHandlerMaker("Failure while recognizing images"))
        
        //Recognizing images from local data
        //A note on the media parameter , it is an array of tuple (String , UIImage) where the string represents the filename
        let img = UIImage(named: "metro-north.jpg")!
        api?.recognizeMedia(Operation.TagAndEmbed, media: [("metro",img)] , success : recognitionHandler , failure : failHandlerMaker("Failure while recognizing media"))
        
        //Sending feedback example
        api?.sendFeedback(["78c742b9dee940c8cf2a06f860025141"] ,dissimilarDocids: ["acd57ec10abcc0f4507475827626785f"],
            success: { str in println("Printing feedback result"); println(str); println("Done printing feedback result.") },
            failure: failHandlerMaker("Failure while getting feedback"))

    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

