//
//  Entry.swift
//  iOS-echoAR-example
//
//  Copyright © echoAR, Inc. 2018-2020.
//
//  Use subject to the Terms of Service available at https://www.echoar.xyz/terms,
//  or another agreement between echoAR, Inc. and you, your company or other organization.
//
//  Unless expressly provided otherwise, the software provided under these Terms of Service
//  is made available strictly on an “AS IS” BASIS WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED.
//  Please review the Terms of Service for details on these and other terms and conditions.
//
//  Created by Alexander Kutner.
//

import Foundation
import SceneKit
import SceneKit.ModelIO

class Entry{
    //saving the URL as where to get the usdz model from EchoAR backend
    var downloadURL:String="";
    //entry ID of the model
    var entryID:String="";
    //server_url passed from EchoAR
    //typical value is: "https://console.echoar.xyz/query?key=<API_Key>"
    var server_url:String="";
    //name of the uploaded file to echoAR
    var filename:String="";
    //name of the usdz file
    var usdz_id:String="";
    //location of the downloaded file
    var storage_loc:URL=URL(fileURLWithPath: "");
    //remote transformations on the object
    var transforms:RemoteTransformation = RemoteTransformation();
    //model node
    var node:SCNNode?
    
    init(entry:String,value:Any,url:String){
        self.entryID=entry;
        self.server_url=url;
        self.parseData(value:value);
    }
    
    //parses the data passed from the database query
    func parseData(value:Any){
        if let dictionary = value as? [String: Any]{
            for (key, value) in dictionary {
                if(key=="hologram"){
                    parseHologram(value:value);
                }
                if(key=="additionalData"){
                    parseAdditionalData(value:value);
                }
            }
        }
        //where we will download the usdz model from
        self.downloadURL=self.server_url+"&file="+self.usdz_id;
    }
    
    //parses the data under hologram attribute
    func parseHologram(value:Any){
        if let holos = value as?[String:Any]{
            for (h_key,h_val) in holos{
                if(h_key=="filename"){
                    self.filename = h_val as! String;
                }
            }
        }
    }
    //parses an additional data attribute and stores it in remote trasformations or as an attr
    func parseAttr(h_key:String,h_val:Any){
        switch h_key{
        case "scale":
            transforms.setScale(scale: (h_val as! NSString).doubleValue)
        case "x":
            let x = (h_val as! NSString).doubleValue
            transforms.setLocation(x: x)
        case "y":
            let y = (h_val as! NSString).doubleValue
            transforms.setLocation(y: y)
        case "z":
            let z = (h_val as! NSString).doubleValue
            transforms.setLocation(z: z)
        case "xAngle":
            let xAng = (h_val as! NSString).doubleValue
            transforms.setRotation(xAng: xAng);
        case "yAngle":
            let yAng = (h_val as! NSString).doubleValue
            transforms.setRotation(yAng: yAng);
        case "zAngle":
            let zAng = (h_val as! NSString).doubleValue
            transforms.setRotation(zAng: zAng);
        case "usdzHologramStorageID":
            self.usdz_id = h_val as! String;
        default:
            break
        }
    }
    
    //parsing info like scale,x,y,z, ect for remote transformations from additional data
    func parseAdditionalData(value:Any){
        if let add_data = value as?[String:Any]{
            for (h_key,h_val) in add_data{
               parseAttr(h_key: h_key, h_val: h_val)
            }
        }
    }
    func updateNode(){
        if(node != nil){
            node!.scale = transforms.getScale();
            node!.position=transforms.getPosition();
            node!.eulerAngles=transforms.getRotation();
        }else{
            print("MODEL ERROR")
            print(self.getName());
        }
    }
    
    func parseWebSock(data:[String]){
        //e.g.: DATA_POST_ENTRY|c4190466-a11d-4057-991d-e514cadb494e|x|0
        parseAttr(h_key:data[2],h_val:data[3])
        //update the model's transformations
        self.updateNode()
        
    }
    //gets the name of the model without the filetype
    //for referencing the name of the node in the scene
    func getName()->String{
        return self.filename.components(separatedBy: ".")[0].replacingOccurrences(of: " ", with: "_")
    }
    
    //returns the entry's scene at the given storage location
    func loadScene(storage_loc:URL) -> SCNScene{
        self.storage_loc=storage_loc;
        let scene = try! SCNScene(url: self.storage_loc);
        scene.background.contents = UIColor.clear;
        let name = self.getName();
        self.node = scene.rootNode.childNode(withName: name, recursively: true);
        //set remote transformations
        self.updateNode()
        return scene
    }
    
    //download the file to put it into the scene
    //saves the download to self.storage_loc
    func downloadFile(completion: (URL) -> ()){
        let savedURL = try! FileManager.default.url(for: .documentDirectory,
                                    in: .userDomainMask,
                                    appropriateFor: nil,
                                    create: false).appendingPathComponent(self.usdz_id)
        //check if already downloaded...
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] as String
        let url = NSURL(fileURLWithPath: path)
        if let pathComponent = url.appendingPathComponent(self.usdz_id) {
            let filePath = pathComponent.path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                print("ASSET ALREADY CACHED");
                self.storage_loc=savedURL;
                completion(savedURL);
                return;
            }else{
                //if not downloaded, download from the download url
                FileManager.default.clearTmpDirectory();
                let downloadURL = URL(string: self.downloadURL)
                print("Loading \(self.filename)")
                let group = DispatchGroup()
                
                let downloadTask = URLSession.shared.downloadTask(with: downloadURL!) {
                    urlOrNil, responseOrNil, errorOrNil in
                    // TODO: check for and handle errors:
                    // * errorOrNil should be nil
                    // * responseOrNil should be an HTTPURLResponse with statusCode in 200..<299
                    guard let fileURL = urlOrNil else { return }
                    do {
                        try FileManager.default.moveItem(at: fileURL, to: savedURL)
                        group.leave();
                    } catch {
                        print ("File Error: \(error)")
                        group.leave();
                    }
                }
                group.enter();
                downloadTask.resume();
                group.wait();
                print("ASSET DOWNLOADED");
                self.storage_loc=savedURL;
                completion(savedURL);
            }
        }
        
        
    }
    
    
    
}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirectory = try contentsOfDirectory(atPath: NSTemporaryDirectory())
            //let docDirectory = try contentsOfDirectory(atPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])
            try tmpDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }
            /*try docDirectory.forEach {[unowned self] file in
                let path = String.init(format: "%@%@", NSTemporaryDirectory(), file)
                try self.removeItem(atPath: path)
            }*/
            
        } catch {
            print(error)
        }
    }
}
