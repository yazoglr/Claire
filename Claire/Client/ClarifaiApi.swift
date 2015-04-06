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
    // TODO : Feedback is not implemented 
    // TODO : Images are not resized
    // TODO : No repeating on Throttle
    // TODO : Tests 
    
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
    
    private var accessToken : String?
    var apiInfo : ApiInfo?
    
    private let maxCallCount : Int = 3;
    
    public typealias FailureHandler = ((FailReason , NSData?) -> Void)
    
    public required init(appID : String , appSecret : String)
    {
        self.appID = appID
        self.appSecret = appSecret
    }
    
    private func getAccesToken(renew : Bool = false , success : String -> Void , failure : FailureHandler)
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
                        if let responseData = data , let json = JSONHelper.decodeJSON(responseData) , let token = json["access_token"] as? String{
                            println("Requesting new token")
                            self?.accessToken = token
                            success(token)
                        } else {
                            failure(.CouldNotGetToken , data)
                        }
                    } else {
                        failure(.CouldNotGetToken, data)
                    }
                } else {
                    failure(.CouldNotGetToken , data)
                }
            }
            
            task.resume()
        }
        else if let accesToken = accessToken {
            println("Using token from the cache")
            success(accesToken) //Could have used forced unwrapping , this feels nicer
        }
    }
    
    func getInfo( success : ApiInfo -> Void , failure : FailureHandler ) {
        if let apiInfo = apiInfo {
            success(apiInfo)
        } else {
            let url = self.urlForEndpoint(.Info)
            let headers = ["Content-Type" : "application/json" ]
            let body = NSMutableData();
            let method = "GET"
            requestWithToken(headers, body: body, method: method, url: url , maxCallCount: maxCallCount, parse:
                { [weak self](dict : JSONHelper.JSONDictionary) -> ApiInfo? in
                    if let results = dict["results"] as? [String : AnyObject] , let minImageSize = results["min_image_size"] as? Int , let maxImageSize = results["max_image_size"] as? Int , let maxBatchSize = results["max_batch_size"] as? Int , let embedAllowed = results["embed_allowed"] as? Bool{
                        
                        let info = ApiInfo(maxImageSize: maxImageSize, minImageSize: minImageSize, maxBatchSize: maxBatchSize, embedAllowed: embedAllowed)
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
                var rec = RecognitionResult()
                // TODO : Local id
                if let result = item["result"] as? [String : AnyObject] {
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
                }
                resultList.append(rec)
            }
            return resultList
        }
        return nil
    }
    
    public func recognizeURLs(op : Operation , urls : [String] , success : ([RecognitionResult] -> Void) , failure : FailureHandler){
        var params = [String : AnyObject]()
        params["op"] = op.description
        params["model"] = "default"
        params["url"] = urls
        
        let headers = [ "Content-Type" : "application/json" ]
        let body = createJSONBody(params)!
        
        recognize(headers, body: body, success: success, failure: failure)
    }
    
    public func recognizeMedia( op : Operation , media : [ ( fileName:String,image : UIImage) ] , success : ([RecognitionResult] -> Void) , failure : FailureHandler) {
        var params = [String : String]()
        params["op"] = op.description
        params["model"] = "default"
        let boundary = "----------asdaadas1ewedbfandaus1edasdassddwwertttr" // TODO : Change
        let body = createMultipartBody(boundary, params : params , media : media)!
        
        let contentType = "multipart/form-data; boundary= \(boundary)"
        let headers = [ "Content-Type" : contentType]
        
        recognize(headers, body: body, success: success, failure: failure)
    }
    
    private func recognize( headers : [String : String ] ,  body : NSData , success : ([RecognitionResult] -> Void) , failure : FailureHandler){
        let method = "POST"
        let url = urlForEndpoint(.Multiop)
        
        requestWithToken(headers, body: body, method: method, url: url, maxCallCount: maxCallCount, parse: dataParser, success: success, failure: failure)
    }
    
    //TODO : Modify 
    //TODO : Add capability of sending feedback using urls
    func sendFeedback( docids : [String] , addTags : [String]? = nil , removeTags : [String]? = nil , similarDocids : [String]? = nil , dissimilarDocids : [String]? = nil , success : ( String -> Void ) , failure : FailureHandler ) -> Void {
        
        // Small closure to convert nil elements into empty strings
        let f : (AnyObject? -> AnyObject) = { optKey in
            if let key = optKey { return key }
            return ""
        }
        
        var params = [String : AnyObject]()
        params["docids"] = f(docids)
        params["add_tags"] = f(addTags)
        params["remove_tags"] = f(removeTags)
        params["similar_docids"] = f(similarDocids)
        params["dissimilar_docids"] = f(dissimilarDocids)
        
        let headers = [ "Content-Type" : "application/json" ]
        
        let body = createJSONBody(params)!
        let method = "POST"
        let url = urlForEndpoint(.Feedback)
        
        //Will change
        let parse : (JSONHelper.JSONDictionary -> String? ) = { s -> String? in return s.description }
        
        requestWithToken(headers, body: body, method: method, url: url, maxCallCount: maxCallCount, parse: parse , success: success, failure: failure)
       
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
        let appendString : (NSMutableData , String) -> Void = { data , str -> Void in data.appendData( NSString(string:str).dataUsingEncoding(NSUTF8StringEncoding)! )}
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
            let header = "Content-Disposition: form-data; name=\"encoded_data\"; filename=\"\(name)\"\r\n" + "Content-Type: image/jpg\r\n\r\n"
            appendString(body,header)
            let imageData = UIImageJPEGRepresentation(image, 100)
            body.appendData(imageData)
            appendString(body,"\r\n")
        }
        
        appendString(body,"--" + boundary + "--\r\n")
        
        return body;
    }
    
    ////TEST FUNCTION - which works btw.
    
//    func tagUrls(urls : [String]){
//        var jDict = [String : AnyObject]()
//        jDict["op"] = "tag,embed"
//        jDict["model"] = "default"
//        jDict["url"] = urls
//        
//        let headers = [ "Content-Type" : "application/json" ]
//        let body = createJSONBody(jDict)!
//        let method = "POST"
//        let url = urlForEndpoint(.Multiop)
//        
//        let failHandler : ( Reason, NSData?) -> Void = { (a,b) in print("FAIL!!!") }
//        
//        requestWithToken(headers, body: body, method: method, url: url, maxCallCount: 3 , parse: { $0 } , success: { println(NSString(data: $0, encoding: NSUTF8StringEncoding))  }, failure: failHandler)
//        
//    }
    
    
    private func requestWithToken<T>(headers : [String:String] , body : NSData , method : String , url : NSURL , maxCallCount : Int , shouldRenewToken:Bool = false , parse : JSONHelper.JSONDictionary -> T? ,  success : T -> Void , failure : (FailReason,NSData?) -> Void ) -> Void
    {
        if(maxCallCount > 0) {
            getAccesToken(renew: shouldRenewToken, success: { [weak self] token -> Void in
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
                                        if let statusCode = jDict["status_code"] as? String where statusCode == "TOKEN_EXPIRED"{
                                            // Token is expired , a new token will be generated and the request will be resent
                                            // IMPORTANT : We are using weak self to avoid retain cycles.
                                            // That means the following recursive call will not be made if
                                            // the ClarifaiApi instance is deallocated at this point. 
                                            // Might wanna take a look at that in the future.
                                            let newCallCount = maxCallCount - 1 //Decreasing the number of calls
                                            self?.requestWithToken(headers, body: body, method: method, url: url, maxCallCount: newCallCount, shouldRenewToken: true, parse: parse, success: success, failure: failure)
                                        } else if let result = parse(jDict) {
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
                                failure( .ApiThrottled , data)
                            } else {
                                failure(.NoSuccessStatusCode(statusCode: httpResponse.statusCode), data)
                                println("T")
                                println(NSString(data: data , encoding: NSUTF8StringEncoding))
                                println(httpResponse.statusCode)
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



