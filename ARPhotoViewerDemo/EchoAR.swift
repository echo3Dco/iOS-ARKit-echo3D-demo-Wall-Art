//
//  echoAR.swift
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

import SceneKit
import Foundation


class EchoAR{
    let api_key="shrill-bird-7026" //insert your echoAR API key here
    //echoar endpoint
    var serverURL="https://console.echoar.xyz/query?key="
    //websocket endpoint
    var websockURL="ws://console.echoar.xyz/message-endpoint"
    //secure websocket endpoint
    //var websockURL="wss://console.echoar.xyz/message-endpoint"
    //url web sessions
    var urlSession: URLSession!
    //entries as a list
    var entries:[Entry]=[]
    //entryID -> Entry
    var entries_dict=[String:Entry]();
    //task for websocket
    var task:URLSessionWebSocketTask!
    
    init(){
        urlSession = URLSession(configuration: .default)
        task = urlSession.webSocketTask(with: URL(string:self.websockURL)!)
        task.resume()
        listen()
        self.sendKey()
    }
    deinit {
        self.disconnect();
    }
    
    //sends the api key to the websocket server
    func sendKey(){
        let message = URLSessionWebSocketTask.Message.string("KEY|"+self.api_key)
        task.send(message, completionHandler: {error-> Void in
            if(error != nil){
                print(error!);
            }
        })
    }
    
    //disconnects from the ws server
    func disconnect() {
        task.cancel(with: .goingAway, reason: nil)
    }
    
    //listens on the websocket server and sends changes to the given entry
    func listen()  {
        task.receive { result in
            switch result {
            case .failure(let error):
                print("Failed to receive message: \(error)")
            case .success(let message):
                switch message {
                case .string(let text):
                    print("Received text message: \(text)")
                    let data_arr = text.components(separatedBy: "|")
                    self.entries_dict[data_arr[1]]?.parseWebSock(data: data_arr)
                case .data(let data):
                    print("Received binary message: \(data)")
                @unknown default:
                    fatalError()
                }
                self.listen();
            }
            
        }
    }
    
    //queries the url and returns the response
    func queryDatabase(api_key:String, completion: ([Entry]) -> ()){
        self.serverURL="https://console.echoar.xyz/query?key="+api_key;
        //check if cached database query
        if(self.entries.count>0){
            //return entries if we've already queried the backend
            completion(self.entries);
        }else{
            //query the server url
            let url=self.serverURL;
            var request = URLRequest(url: URL(string: url)!);
            request.httpMethod = "GET";
            let session = URLSession.shared;
            let group = DispatchGroup()
            group.enter()
            //async api call
            let task = session.dataTask(with: request, completionHandler: { data, response, error -> Void in
                do {
                    let json = try! JSONSerialization.jsonObject(with: data!) as! Dictionary<String, AnyObject>
                    if(json["db"] != nil){
                        print("Loading Database...")
                        self.parseDatabse(json:json["db"]);
                    }else{
                        print("Connection Error")
                    }
                    group.leave()
                }
            });
            task.resume();
            group.wait();
            completion(self.entries);
        }
    }
    //iterating through the database and saving the entry data
    func parseDatabse(json:AnyObject?){
        if let dictionary = json as? [String: Any]{
            for (entry, value) in dictionary {
                print("Loading Entry: \(entry)");
                parseEntry(key:entry,entry:Entry(entry:entry,value:value,url:serverURL));
            }
        }
    }
    //saving the data from the entry into an object
    func parseEntry(key:String, entry:Entry){
        self.entries.append(entry);
        self.entries_dict[key]=entry;
    }

    //getter for list of entries
    func getEntries() -> [Entry]{
        return self.entries;
    }
    
    //loads the scene of the netry at the given index
    func loadSceneAtIndex(index:Int, completion: (SCNScene) -> ()){
        //queryDatabase caches results
        self.queryDatabase(api_key: api_key, completion: { (entry_list) -> () in
            let entry = entry_list[index]
            entry.downloadFile(completion:{(storage_id) -> () in
                let scene = entry.loadScene(storage_loc:storage_id);
                completion(scene);
            });
        });
    }
    
    //loads the scene of the entry at the given filename
    func loadSceneFromFilename(filename:String, completion: (SCNScene)->()){
        //search through entries to find if filename is one
        self.queryDatabase(api_key: api_key, completion: { (entries) in
            var ind=0;
            for entry in entries{
                if entry.filename==filename{
                    //load the object at the index
                    //NOTE: this loads the FIRST object with the file name that is in the entry list
                    //there can be duplicates
                    loadSceneAtIndex(index: ind, completion: {(scene)-> () in
                        completion(scene);
                        return;
                    });
                }
                ind+=1;
            }
        });
        //if there is none print error and return blank scene
        print("NO FILE WITH GIVEN NAME FOUND")
        completion(SCNScene());
    }
    //loads the entry as a scene of the given ID
    func loadSceneFromEntryID(entryID:String, completion: (SCNScene)->()){
        //search through entries to find if entryID is contained
        self.queryDatabase(api_key: api_key, completion: { (entries) in
            var ind=0;
            for entry in entries{
                if entry.entryID==entryID{
                    //load the object at the index
                    loadSceneAtIndex(index: ind, completion: {(scene)-> () in
                        completion(scene);
                        return;
                    });
                }
                ind+=1;
            }
        });
        //if there is none print error and return blank scene
        print("NO FILE WITH GIVEN EntryID FOUND")
        completion(SCNScene());
    }
    
    //loads a SCNNode from a given index so it can be added to a scene
    func loadNodeFromIndex(index:Int, completion: (SCNNode) -> ()){
        loadSceneAtIndex(index: index) { (scene) in
            let entry=self.getEntries()[index];
            let name = entry.getName();
            //find the child node of the scene with the given model name
            let node = scene.rootNode.childNode(withName: name, recursively: true);
            if (node !== nil){
                completion(node!);
            }else{
                completion(SCNNode());
            }
        }
    }
    
    //loads all the model entries as SCNNodes
    func loadAllNodes(completion: ([SCNNode]) -> ()){
        self.queryDatabase(api_key: api_key, completion: { (entry_list) -> () in
            var node_list:[SCNNode] = []
            for entry in entry_list{
                entry.downloadFile(completion: { (url)-> () in
                    let scene = entry.loadScene(storage_loc:url);
                    let node = scene.rootNode.childNode(withName: entry.getName(), recursively: true);
                    if (node !== nil){
                        node_list.append(node!)
                    }else{
                        print("Failed to load model :\(entry.filename)")
                    }
                    
                });
            }
            completion(node_list)
        });
    
    
    }

    
}
