//
//  ViewController.swift
//  ARPhotoViewerDemo
//
//  Created by DAYE JACK on 10/1/20.
//  Copyright © 2020 DAYE JACK. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var togglePlaneButton: UIButton!
    
    @IBOutlet weak var previewImageView: UIImageView!
    @IBOutlet weak var imageAddedText: UILabel!
    var planeColor: UIColor?
    var planeColorOff: UIColor?
    var chosenImage: UIImage?
    var planes: [SCNNode] = []
    var e: EchoAR?
    
    let echoImgEntryId = "ef28bae9-5e6a-4174-9a64-c3773ff59e17" // ENTER YOUR ECHO AR ENTRY ID FOR A PICTURE FRAME
    
    var pictureFrameNode: SCNNode?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //set the color to use for the plane
        planeColor = UIColor(red: CGFloat(102.0/255) , green: CGFloat(189.0/255), blue: CGFloat(60.0/255), alpha: CGFloat(0.6))
        
        //plane color off will be used as the color of our planes when they are toggled off
        planeColorOff = UIColor(red: CGFloat(102.0/255) , green: CGFloat(189.0/255), blue: CGFloat(60.0/255), alpha: CGFloat(0.0))
        
        //initialize our echo ar objec
        e = EchoAR()
        
        //set scene view to automatically add omni directional light when needed
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        //set our session configuration, so we are tracking vertical planes
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        sceneView.session.run(configuration)

        sceneView.delegate = self
        
        //show debug feature points
        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        
        //add gesture recognizer, to perform some action whenever the user taps
        //the scene view
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(screenTapped(gesture:)))
        sceneView.addGestureRecognizer(gestureRecognizer)
        
        //make the view and text that appear when a user adds an image invisible.
        imageAddedText.alpha = 0.0
        previewImageView.alpha = 0.0
    }
    
    override func viewDidAppear(_ animated: Bool) {
        //when the view appears, present an alert to the user
        //letting them know to scan a horizontal surface
        let alert = UIAlertController(title: "Scan And Get Started", message: "Move your phone around to scan a vertical plane (find a vertical surface with a pattern for ease with scanning)", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }


    
    @IBAction func addPhotoTapped(_ sender: Any) {
        //when the user taps a photo
        //display an image picker which allows the user to select a photo
        //from their device
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }
    
    
    /*
     screenTapped(gesture:)
     takes a tap gesture recognizer as an argument
     calls addImage() -- to add an image on the tapped location
     */
    @objc func screenTapped(gesture: UITapGestureRecognizer){
        let gesturePos = gesture.location(in: self.sceneView)
        
        //get a 3D point from the tapped location
        //check if the user tapped an existing plane
        let hitTestResults = sceneView.hitTest(gesturePos, types: .existingPlaneUsingExtent)
        
        //check if there was a result to the hit test
        guard let hitTest = hitTestResults.first, let _ = hitTest.anchor else {
            return
        }
        
        //add image using hit test
        addImage(hitTest)
    }
    
    func addImage(_ hitTest: ARHitTestResult){
        //create a plane
        let planeGeometry = SCNPlane(width: 0.2, height: 0.35)
        let material = SCNMaterial()
        planeGeometry.materials = [material]
        
        //check if the user has selected an image
        guard chosenImage != nil else{
            return
        }
        
        //attach the image to the plane
        material.diffuse.contents = chosenImage
        
        //create a node from our plane
        let imageNode = SCNNode(geometry: planeGeometry)
        
        //match the image transform to the hit test anchor transform
        imageNode.transform = SCNMatrix4(hitTest.anchor!.transform)
        
        //rotate the node so it stands up vertically, rather than lying flat
        imageNode.eulerAngles = SCNVector3(imageNode.eulerAngles.x + (-1 * .pi / 2), imageNode.eulerAngles.y, imageNode.eulerAngles.z)
        
        //position node using the hit test
        imageNode.position = SCNVector3(hitTest.worldTransform.columns.3.x, hitTest.worldTransform.columns.3.y, hitTest.worldTransform.columns.3.z)
        
        //load picture frame from echoAR platform, using its entry id
        e!.loadSceneFromEntryID(entryID: echoImgEntryId, completion: { (scene) in
            //get the picture frame node
            guard let selectedNode = scene.rootNode.childNodes.first else {return}
            
            //position selected node (picture frame), slightly behind the image, and set the euler angles
            // of the selected node
            selectedNode.position = SCNVector3(hitTest.worldTransform.columns.3.x, hitTest.worldTransform.columns.3.y, hitTest.worldTransform.columns.3.z - 0.01)
            selectedNode.eulerAngles = imageNode.eulerAngles
            
            //scale down picture frame node
            //0.043 is a number arrived at through trial, that gives a good picture frame size for our image
            let action = SCNAction.scale(by: 0.043, duration: 0.3)
            selectedNode.runAction(action)
            
            //add picture frame to scene
            self.sceneView.scene.rootNode.addChildNode(selectedNode)
        })
        
        
        //add image to scene
        sceneView.scene.rootNode.addChildNode(imageNode)
        
    }
    
    

    
    //MARK: image picker delegate
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        //get the users selected image
        guard let image = info[.editedImage] as? UIImage else {return}
        self.chosenImage = image;

        self.dismiss(animated: true) {
            //show a preview of the users selected image
            //and show text prompt to user
            self.imageAddedText.alpha = 1.0
            self.previewImageView.image = image
            self.previewImageView.alpha = 1.0
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        //if a user clicks cancel when adding an image,
        //dismiss the image picker
        self.dismiss(animated: true, completion: nil)
    }
    
    //END image picker delegate
 
    @IBAction func togglePlaneTapped(_ sender: Any) {
        //if toggle plane tapped,
           //iterate through all horizontal planes, and set their alpha's to 0.0
           for plane in planes {
                  togglePlane(planeNode: plane)
           }

           //change the state of the toggle plane button (dim or undimmed)
           togglePlaneButton.alpha = togglePlaneButton.alpha < 0.5 ? 1.0 : 0.3
           print(togglePlaneButton.alpha)
    }
    
    //togglePlane(planeNode:): takes a SCNNode as an argument
    //depending on the state of the togglePlaneButton, changes the color
    //of planeNode. (either to fully transparent, or to a translucent green)
    func togglePlane(planeNode: SCNNode){
        //make plane visible or invisible, by changing its color
        if togglePlaneButton.alpha.isEqual(to: 1.0) {
           planeNode.geometry?.materials.first?.diffuse.contents = planeColorOff
        }
        else {
            planeNode.geometry?.materials.first?.diffuse.contents = planeColor
        }
    }
    
}

//MARK: ARSCN View Delegate
extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, let planeNode = node.childNodes.first,
            let plane = planeNode.geometry as? SCNPlane
            else {return}

        //update the plane node, as plane anchor information updates

        //get the width and the height of the planeAnchor
        let w = CGFloat(planeAnchor.extent.x)
        let h = CGFloat(planeAnchor.extent.z)

        //set the plane to the new width and height
        plane.width = w
        plane.height = h

        //get the x y and z position of the plane anchor
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)

        //set the nodes position to the new x,y, z location
        planeNode.position = SCNVector3(x, y, z)
    }

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }

        //add a plane node to the scene

        //get the width and height of the plane anchor
        let w = CGFloat(planeAnchor.extent.x)
        let h = CGFloat(planeAnchor.extent.z)

        //create a new plane
        let plane = SCNPlane(width: w, height: h)

        //set the color of the plane
        plane.materials.first?.diffuse.contents = planeColor!

        //create a plane node from the scene plane
        let planeNode = SCNNode(geometry: plane)

        //get the x, y, and z locations of the plane anchor
        let x = CGFloat(planeAnchor.center.x)
        let y = CGFloat(planeAnchor.center.y)
        let z = CGFloat(planeAnchor.center.z)

        //set the plane position to the x,y,z postion
        planeNode.position = SCNVector3(x,y,z)

        //turn th plane node so it lies flat vertically, rather than stands up vertically
        planeNode.eulerAngles.x = -.pi / 2

        //set the name of the plane
        planeNode.name = "plane"

        //add plane to scene
        node.addChildNode(planeNode)
        
        //save plane (so it can be edited later)
        planes.append(planeNode)
    }
    
    
    
}
