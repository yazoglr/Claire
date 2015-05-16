//
//  ClarifaiApi.swift
//  Claire
//
//  Created by Yağızhan Güler on 15/02/15.
//  Copyright (c) 2015 Yağızhan Güler. All rights reserved.
//

import Foundation
import UIKit

public class ClarifaiApi
{
    // TODO : Tests 
    // TODO : Better failure formation and handling
    
    public typealias FailureHandler = ((FailReason , NSData?) -> Void)
    
    enum Endpoint : String
    {
        case Token = "/token"
        case Info = "/info"
        case Tag = "/tag"
        case Multiop = "/multiop"
        case Feedback = "/feedback"
        case Embed = "/embed"
    }
    
    internal let appID : String
    internal let appSecret : String
    
    private let baseURL : NSURL = NSURL(string : "https://api.clarifai.com")!
    private let apiVersion = "v1"
    private let defaultModel : String = "default"
    
    
    private var accessToken : String?
    public private(set) var apiInfo : ApiInfo?
    
    private let maxCallCount : Int = 3
    
    
    private var canResize : Bool = true
    private var shouldRepeatOnThrottle : Bool = false
    
    // Hardcoding the values might not be good practice
    private var maxImageSize : CGFloat {
        get { return apiInfo?.maxImageSize ?? 1024.0 }
    }
    private var minImageSize : CGFloat {
        get { return apiInfo?.minImageSize ?? 448.0 }
    }
    
    public required init(appID : String , appSecret : String)
    {
        self.appID = appID
        self.appSecret = appSecret
    }
    
    private func getAccessToken(renew : Bool = false , success : String -> Void , failure : FailureHandler)
    {
        if renew || accessToken == nil
        {
            //Hardcoded , will modify
            let url = self.urlForEndpoint(.Token)
            let request = NSMutableURLRequest(URL : url)
            request.HTTPMethod = "POST"
            let contentType = "application/x-www-form-urlencoded"
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
            let str = "grant_type=client_credentials&client_id=\(appID)&client_secret=\(appSecret)"
            request.HTTPBody = str.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)

            let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { [weak self] data , response , error in
                if let httpResponse = response as? NSHTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        if let responseData = data {
                            if let json = JSONHelper.decodeJSON(responseData) {
                                if let token = json["access_token"] as? String {
                                    println("Requesting new token")
                                    self?.accessToken = token
                                    success(token)
                                } else {
                                    failure(FailReason.CouldNotGetToken(secondaryReason : FailReason.CouldNotParseJSON) , data)
                                }
                            } else {
                                failure(FailReason.CouldNotGetToken(secondaryReason : FailReason.CouldNotParseData) , data)
                            }
                        } else {
                            failure(FailReason.CouldNotGetToken(secondaryReason : FailReason.NoData) , data)
                        }
                    } else {
                        failure(FailReason.CouldNotGetToken(secondaryReason:FailReason.NoSuccessStatusCode(statusCode: httpResponse.statusCode)), data)
                    }
                } else {
                    failure(FailReason.CouldNotGetToken(secondaryReason : FailReason.Other(error)) , data)
                }
            }
            
            task.resume()
        }
        else {
            println("Using token from the cache")
            success(accessToken!)
        }
    }
    
   public func getInfo( success : ApiInfo -> Void , failure : FailureHandler ) {
        if let apiInfo = apiInfo {
            success(apiInfo)
        } else {
            let url = self.urlForEndpoint(.Info)
            let headers = ["Content-Type" : "application/json" ]
            let body = NSMutableData();
            let method = "GET"
            requestWithToken(headers, body: body, method: method, url: url , maxCallCount: self.maxCallCount, shouldRepeatOnThrottle : self.shouldRepeatOnThrottle , parse:
                { [weak self](dict : JSONHelper.JSONDictionary) -> ApiInfo? in
                    if let sCode = dict["status_code"] as? String , let sMsg = dict["status_msg"] as? String , let results = dict["results"] as? [String : AnyObject] , let minImageSize = results["min_image_size"] as? CGFloat , let maxImageSize = results["max_image_size"] as? CGFloat , let maxBatchSize = results["max_batch_size"] as? Int , let embedAllowed = results["embed_allowed"] as? Bool{
                        
                        let info = ApiInfo(maxImageSize: maxImageSize, minImageSize: minImageSize, maxBatchSize: maxBatchSize, embedAllowed: embedAllowed , statusCode : sCode , statusMessage : sMsg)
                        self?.apiInfo = info;
                        return info;
                    }
                    return nil
                } , success: success, failure: failure)
        }
    }
    
    // TODO : Not very elegant , modify
    private func dataParser( dict : JSONHelper.JSONDictionary ) -> [RecognitionResult]? {
       //println(dict) // for debugging purposes
        
        if let results = dict["results"] as? [AnyObject] {
            var resultList = [RecognitionResult]()
            for item in results {
                // TODO : Local id
                if let result = item["result"] as? [String : AnyObject] , let statusCode = item["status_code"] as? String , let statusMessage = item["status_msg"] as? String {
                    
                    var rec = RecognitionResult(statusCode: statusCode, statusMessage: statusMessage)
                    
                    if let embedArr = result["embed"] as? [Double] {
                        rec.embed = embedArr
                    }
                    
                    if let tag = result["tag"] as? [String : AnyObject] , let classNames = tag["classes"] as? [String] , let probs = tag["probs"] as? [Double] {
                        var tags : [RecognitionResult.Tag] = []
                        let smaller = min(classNames.count, probs.count)
                        for i in 0..<smaller{
                            tags.append((className : classNames[i] , prob : probs[i]))
                        }
                        rec.tags = tags
                    }
                    resultList.append(rec)
                }
            }
            return resultList
        }
        return nil
    }
    
    public func recognizeURLs(op : Operation , model : String = "default" ,  urls : [String] , success : ([RecognitionResult] -> Void) , failure : FailureHandler){
        var params = JSONHelper.JSONDictionary()
        params["op"] = op.description
        params["model"] = model
        params["url"] = urls
        
        let headers = [ "Content-Type" : "application/json" ]
        let body = createJSONBody(params)!
        
        recognize(headers, body: body, success: success, failure: failure)
    }
    
    public func recognizeMedia( op : Operation , model : String = "default" , media : [ ( fileName:String,image : UIImage) ] , success : ([RecognitionResult] -> Void) , failure : FailureHandler) {
        
        var params = [String : String]()
        params["op"] = op.description
        params["model"] = model
        let boundary = "----------asdaadas1ewedbfandaus1edasdassddwwertttr" // TODO : Change
        let body = createMultipartBody(boundary, params : params , media : media)!
        
        let contentType = "multipart/form-data; boundary= \(boundary)"
        let headers = [ "Content-Type" : contentType]
        
        recognize(headers, body: body, success: success, failure: failure)
    }
    
    private func recognize( headers : [String : String ] ,  body : NSData , success : ([RecognitionResult] -> Void) , failure : FailureHandler){
        let method = "POST"
        let url = urlForEndpoint(.Multiop)
        
        requestWithToken(headers, body: body, method: method, url: url, maxCallCount: self.maxCallCount, shouldRepeatOnThrottle : self.shouldRepeatOnThrottle , parse: dataParser, success: success, failure: failure)
    }
    
    //TODO : Modify 
    //TODO : Add capability of sending feedback using urls
    func sendFeedback( docids : [String] , addTags : [String]? = nil , removeTags : [String]? = nil , similarDocids : [String]? = nil , dissimilarDocids : [String]? = nil , success : ( FeedbackResult -> Void ) , failure : FailureHandler ) -> Void {
        
        var params = JSONHelper.JSONDictionary()
        params["docids"] = docids ?? ""
        params["add_tags"] = addTags ?? ""
        params["remove_tags"] = removeTags ?? ""
        params["similar_docids"] = similarDocids ?? ""
        params["dissimilar_docids"] = dissimilarDocids ?? ""
        
        let headers = [ "Content-Type" : "application/json" ]
        let body = createJSONBody(params)!
        let method = "POST"
        let url = urlForEndpoint(.Feedback)
        
        //Will change
        let parse : (JSONHelper.JSONDictionary -> FeedbackResult? ) = { jsonArr -> FeedbackResult? in
            if let sCode = jsonArr["status_code"] as? String , let sMsg = jsonArr["status_msg"] as? String {
                return FeedbackResult(statusCode: sCode, statusMessage: sMsg)
            }
            return nil
        }
        
        requestWithToken(headers, body: body, method: method, url: url, maxCallCount: self.maxCallCount, shouldRepeatOnThrottle : self.shouldRepeatOnThrottle , parse: parse , success: success, failure: failure)
       
    }
    
    private func urlForEndpoint(endpoint : Endpoint) -> NSURL
    {
        return baseURL.URLByAppendingPathComponent("/\(apiVersion)\(endpoint.rawValue)")
    }
    
    private func createJSONBody(params : [String : AnyObject]) -> NSData?
    {
        //var jDict = [String : AnyObject]()
        //jDict["op"] = "tag"
        //jDict["model"] = model
        //jDict["url"] = urls
        
        return JSONHelper.encodeJSON(params)
    }
    
    //Boundary might be converted to inout.
    //Currently the return value is never optional , dangerous forced unwrapping exists. Might wanna change that.
    private func createMultipartBody(boundary : String , params : [String : String] , media : [ ( fileName:String,image : UIImage) ]) -> NSData?
    {
        let appendString : (NSMutableData , String) -> Void = { data , str -> Void in data.appendData( (str as NSString).dataUsingEncoding(NSUTF8StringEncoding)! )}
        let appendBoundary : (NSMutableData -> Void) = { data -> Void in  appendString(data , "--\(boundary)\r\n")  }
        
        let body = NSMutableData()
        
        //Writing the parameters
        for (key , value) in params {
            appendBoundary(body)
            let str = "Content-Disposition: form-data; " + "name=\"" + key + "\"\r\n\r\n" + value + "\r\n";
            appendString(body,str)
        }
        
        //Write the media
        for (name , image) in media {
            appendBoundary(body)
            let header = "Content-Disposition: form-data; name=\"encoded_data\"; filename=\"\(name)\"\r\n" + "Content-Type: image/jpeg\r\n\r\n"
            appendString(body,header)
            let processedImg = canResize ? self.processImage(image) : image;
//            println(processedImg.size.width)
//            println(processedImg.size.height)
            
            // TODO : Resizing not working might be related to the conversion of UIImage to NSData , look it up
            // Observed that Clarifai detects the dimensions of the resized image always as 2 * (intendedSize) ; when the intented size is
            // dropped to the half of the max value , whole operation works. Thus , it should not be that hard to get it right.
            let imageData = UIImageJPEGRepresentation(processedImg, 90)
            body.appendData(imageData)
            appendString(body,"\r\n")
        }
        
        appendString(body,"--" + boundary + "--\r\n")
        
        return body;
    }
    
    // Returns a resized version of the image if it is too big or too small. Otherwise , returns the original image.
    private func processImage(image : UIImage) -> UIImage {
        if(image.size.width > maxImageSize || image.size.height > maxImageSize){
            println("Image is too big , resizing")
            let wScale = maxImageSize / image.size.width
            let hScale = maxImageSize / image.size.height
            let imgScale = wScale < hScale ? wScale : hScale;
            
            return self.scaleImage(image , scale: imgScale)
        }
        else if(image.size.width < minImageSize || image.size.height < minImageSize){
            println("Image is too small , resizing")
            let wScale = minImageSize / image.size.width
            let hScale = minImageSize / image.size.height
            let imgScale = wScale > hScale ? wScale : hScale;
            
            return self.scaleImage(image , scale: imgScale)
        }
        else {
            return image
        }
    }
    
    private func scaleImage(image : UIImage , scale : CGFloat ) -> UIImage {
        let size = CGSizeApplyAffineTransform(image.size, CGAffineTransformMakeScale(scale, scale))
        
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.drawInRect(CGRect(origin: CGPointZero, size: size))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return scaledImage
    }
    
    
    // TODO : Consider using gcd to make sure success and fail handlers are called from the main thread
    private func requestWithToken<T>(headers : [String:String] , body : NSData , method : String , url : NSURL , maxCallCount : Int , shouldRenewToken:Bool = false , shouldRepeatOnThrottle : Bool = false , parse : JSONHelper.JSONDictionary -> T? ,  success : T -> Void , failure : (FailReason,NSData?) -> Void ) -> Void
    {
        if(maxCallCount > 0) {
            getAccessToken(renew: shouldRenewToken, success: { [weak self] token -> Void in
                    let request = NSMutableURLRequest(URL: url)
                    request.setValue("Bearer \(token)" , forHTTPHeaderField: "Authorization" )
                    for(key , value) in headers{
                        request.setValue(value, forHTTPHeaderField: key)
                    }
                    request.HTTPBody = body;
                    request.HTTPMethod = method;
                    let task = NSURLSession.sharedSession().dataTaskWithRequest(request) { (data , response , error) -> Void in
                        if let httpResponse = response as? NSHTTPURLResponse {
                            if httpResponse.statusCode == 200 || httpResponse.statusCode == 201 { 
                                if let data = data {
                                    if let jDict = JSONHelper.decodeJSON(data) {
                                        if let result = parse(jDict) {
                                            success(result)
                                        } else {
                                            failure(.CouldNotParseJSON, data)
                                        }
                                    } else {
                                        failure(.CouldNotParseData, data)
                                    }
                                } else {
                                    failure(.NoData, data)
                                }
                            } else if httpResponse.statusCode == 429 {
                                //TODO : Make it possible to wait x secs and repeat the request
                                println("Throttled")
                                if(shouldRepeatOnThrottle){
                                    //Decreasing the max number of calls and repeating the request.
                                    self?.requestWithToken(headers, body: body, method: method, url: url, maxCallCount: maxCallCount - 1, shouldRepeatOnThrottle: true, parse: parse, success: success, failure: failure)
                                } else {
                                    failure( .ApiThrottled , data)
                                }
                            } else if httpResponse.statusCode == 401 {
                                // Token is expired or invalid , a new token will be generated and the request will be resent
                                // IMPORTANT : We are using weak self to avoid retain cycles.
                                // That means the following recursive call will not be made if
                                // the ClarifaiApi instance is deallocated at this point.
                                // Might wanna take a look at that in the future.
                                println("Token expired or invalid , will request new token")
                                let newCallCount = maxCallCount - 1 //Decreasing the number of calls
                                self?.requestWithToken(headers, body: body, method: method, url: url, maxCallCount: newCallCount, shouldRenewToken: true, parse: parse, success: success, failure: failure)
                            } else {
                                failure(.NoSuccessStatusCode(statusCode: httpResponse.statusCode), data)
                            }
                        } else {
                            failure(.Other(error), data)
                        }
                    }
                
                    task.resume()
                },
                
                failure: failure)
        }
        else{
            failure(.ReachedMaxNumberOfCalls , nil)
        }
        
    }
}



