//
//  RemoteTransformation.swift
//  EchoAR-iOS-SceneKit
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
//stores remote transformations for an entry
class RemoteTransformation{
    var scale:Double = 1.0;
    var x=0.0;
    var y=0.0;
    var z=0.0;
    var xAng=0.0;
    var yAng=0.0;
    var zAng=0.0;
    init(){
    }
    //sets the scale of the model
    func setScale(scale:Double){
        self.scale=scale;
    }
    //set location
    func setLocation(x:Double){
        self.x=x;
    }
    func setLocation(y:Double){
        self.y=y;
    }
    func setLocation(z:Double){
        self.z=z;
    }
    func getScale() -> SCNVector3{
        return SCNVector3(self.scale,self.scale,self.scale);
    }
    func setRotation(xAng:Double){
        self.xAng=xAng;
    }
    func setRotation(yAng:Double){
        self.yAng=yAng;
    }
    func setRotation(zAng:Double){
        self.zAng=zAng;
    }
    func getRotation()->SCNVector3{
        return SCNVector3(self.xAng,self.yAng,self.zAng);
    }
    //default position is in front of and slightly below camera
    //then add transformations from there
    func getPosition() -> SCNVector3 {
        return SCNVector3(0+self.x,-2+self.y,-5+self.z);
    }
    
}
