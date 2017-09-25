/**
 * Copyright (c) 2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import GameplayKit
import SceneKit
import SpriteKit

class GameViewController: UIViewController {
  
  let helper = GameHelper()
  var menuScene = SCNScene.init(named: "resources.scnassets/Menu.scn")!
  var levelScene = SCNScene.init(named: "resources.scnassets/Level.scn")!
  var cameraNode: SCNNode!
  var shelfNode: SCNNode!
  var baseCanNode: SCNNode!
  var currentBallNode: SCNNode?
  
  lazy var touchCatchingPlaneNode: SCNNode = {
    let node = SCNNode.init(geometry: SCNPlane.init(width: 40, height: 40))
    node.opacity = 0.001
    node.castsShadow = false
    return node
  }()
  
  // Accessor for the SCNView
  var scnView: SCNView {
    let scnView = view as! SCNView
    
    scnView.backgroundColor = UIColor.black
    
    return scnView
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    presentMenu()
    createScene()
    createLevelsFrom(baseNode: shelfNode)
  }
  
  func presentMenu() {
    let hudNode = menuScene.rootNode.childNode(withName: "hud", recursively: true)!
    hudNode.geometry?.materials = [helper.menuHUDMaterial]
    hudNode.rotation = SCNVector4.init(x: 1, y: 0, z: 0, w: .pi)
    
    helper.state = .tapToPlay
    
    let transition = SKTransition.crossFade(withDuration: 1)
    scnView.present(menuScene,
                    with: transition,
                    incomingPointOfView: nil,
                    completionHandler: nil)
  }
  
  func presentLevel() {
    setupNextLevel()
    levelScene.physicsWorld.gravity = SCNVector3.init(x: 0, y: -1, z: 0)
    helper.state = .playing
    let transition = SKTransition.crossFade(withDuration: 1)
    scnView.present(levelScene,
                    with: transition,
                    incomingPointOfView: nil,
                    completionHandler: nil)
  }
  
  func createScene() {
    cameraNode = levelScene.rootNode.childNode(withName: "camera", recursively: true)!
    shelfNode = levelScene.rootNode.childNode(withName: "shelf", recursively: true)!
    
    guard let canScene = SCNScene.init(named: "resources.scnassets/Can.scn") else { return }
    baseCanNode = canScene.rootNode.childNode(withName: "can", recursively: true)!
    
    let shelfPhysicsBody = SCNPhysicsBody.init(type: .static, shape: SCNPhysicsShape.init(geometry: shelfNode.geometry!))
    shelfPhysicsBody.isAffectedByGravity = false
    shelfNode.physicsBody = shelfPhysicsBody
    
    levelScene.rootNode.addChildNode(touchCatchingPlaneNode)
    touchCatchingPlaneNode.position = SCNVector3.init(x: 0, y: 0, z: shelfNode.position.z)
    touchCatchingPlaneNode.eulerAngles = cameraNode.eulerAngles
  }
  
  func setupNextLevel() {
    if helper.ballNodes.count > 0 {
      helper.ballNodes.removeLast()
    }
    
    let level = helper.levels[helper.currentLevel]
    for index in 0..<level.canPositions.count {
      let canNode = baseCanNode.clone()
      canNode.geometry = baseCanNode.geometry!.copy() as? SCNGeometry
      canNode.geometry!.firstMaterial = baseCanNode.geometry!.firstMaterial!.copy() as? SCNMaterial
      
      let shouldCreateBaseVariation = GKRandomSource.sharedRandom().nextInt() % 2 == 0
      
      canNode.eulerAngles = SCNVector3.init(x: 0, y: shouldCreateBaseVariation ? -110 : 55, z: 0)
      canNode.name = "Can #\(index)"
      
      if let materials = canNode.geometry?.materials {
        for material in materials where material.multiply.contents != nil {
          if shouldCreateBaseVariation {
            material.multiply.contents = "resources.scnassets/Can_Diffuse-2.png"
          } else {
            material.multiply.contents = "resources.scnassets/Can_Diffuse-1.png"
          }
        }
      }
      
      let canPhysicsBody = SCNPhysicsBody.init(type: .dynamic, shape: SCNPhysicsShape.init(geometry: SCNCylinder.init(radius: 0.33, height: 1.25), options: nil))
      canPhysicsBody.mass = 0.75
      canPhysicsBody.contactTestBitMask = 1
      canNode.physicsBody = canPhysicsBody
      
      canNode.position = level.canPositions[index]
      
      levelScene.rootNode.addChildNode(canNode)
      helper.canNodes.append(canNode)
    }
    
    let waitAction = SCNAction.wait(duration: 1.0)
    let blockAction = SCNAction.run { _ in
      self.dispenseNewBall()
    }
    let sequenceAction = SCNAction.sequence([waitAction, blockAction])
    levelScene.rootNode.runAction(sequenceAction)
  }
  
  func createLevelsFrom(baseNode: SCNNode) {
    // Level 1
    let levelOneCanOne = SCNVector3(
      x: baseNode.position.x - 0.5,
      y: baseNode.position.y + 0.62,
      z: baseNode.position.z
    )
    let levelOneCanTwo = SCNVector3(
      x: baseNode.position.x + 0.5,
      y: baseNode.position.y + 0.62,
      z: baseNode.position.z
    )
    let levelOneCanThree = SCNVector3(
      x: baseNode.position.x,
      y: baseNode.position.y + 1.75,
      z: baseNode.position.z
    )
    let levelOne = GameLevel(
      canPositions: [
        levelOneCanOne,
        levelOneCanTwo,
        levelOneCanThree
      ]
    )
    
    // Level 2
    let levelTwoCanOne = SCNVector3(
      x: baseNode.position.x - 0.65,
      y: baseNode.position.y + 0.62,
      z: baseNode.position.z
    )
    let levelTwoCanTwo = SCNVector3(
      x: baseNode.position.x - 0.65,
      y: baseNode.position.y + 1.75,
      z: baseNode.position.z
    )
    let levelTwoCanThree = SCNVector3(
      x: baseNode.position.x + 0.65,
      y: baseNode.position.y + 0.62,
      z: baseNode.position.z
    )
    let levelTwoCanFour = SCNVector3(
      x: baseNode.position.x + 0.65,
      y: baseNode.position.y + 1.75,
      z: baseNode.position.z
    )
    let levelTwo = GameLevel(
      canPositions: [
        levelTwoCanOne,
        levelTwoCanTwo,
        levelTwoCanThree,
        levelTwoCanFour
      ]
    )
    
    helper.levels = [levelOne, levelTwo]
  }
  
  func dispenseNewBall() {
    // 1
    let ballScene = SCNScene(named: "resources.scnassets/Ball.scn")!
    
    let ballNode = ballScene.rootNode.childNode(withName: "sphere", recursively: true)!
    ballNode.name = "ball"
    let ballPhysicsBody = SCNPhysicsBody(
      type: .dynamic,
      shape: SCNPhysicsShape(geometry: SCNSphere(radius: 0.35))
    )
    ballPhysicsBody.mass = 3
    ballPhysicsBody.friction = 2
    ballPhysicsBody.contactTestBitMask = 1
    ballNode.physicsBody = ballPhysicsBody
    ballNode.position = SCNVector3(x: -1.75, y: 1.75, z: 8.0)
    ballNode.physicsBody?.applyForce(SCNVector3(x: 0.825, y: 0, z: 0), asImpulse: true)
    
    // 2
    currentBallNode = ballNode
    levelScene.rootNode.addChildNode(ballNode)
  }
  
  // MARK: - Touches
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    if helper.state == .tapToPlay {
      presentLevel()
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    
  }
  
  // MARK: - ViewController Overrides
  override var prefersStatusBarHidden : Bool {
    return true
  }
  
  override var supportedInterfaceOrientations : UIInterfaceOrientationMask {
    return UIDevice.current.userInterfaceIdiom == .phone ? .portrait : .all
  }
  
}
