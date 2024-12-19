import ARKit
import RealityKit
import CoreLocation
import simd
import SitumSDK

@available(iOS 15.0, *)

class Coordinator: NSObject, ARSessionDelegate {
    var locationManager: LocationManager
    var arrowAnchor: AnchorEntity?
    var fixedAnchor: AnchorEntity?
    var arSceneHandler: ARSceneHandler?

    var arView: ARView?
    var yawLabel: UILabel?

    var isDebugEnabled = false
    
    var targetX = 0.0
    var targetZ = 0.0
    var targetFloorIdentifier = 0
    var arrowDistance = 5.0
    var hasToRefresh = true
    
    var pointsList: [[String: Any]] = []
    var storedTransformedPositions: [SIMD3<Float>] = []
    var poisStored: [String: Any] = [:]
    
    var lastUpdateTime = 0.0
    var destinationPoiName: String? = nil
    var modelManager = DynamicModelManager()
    
    
    init(locationManager: LocationManager) {        
        self.locationManager = locationManager
    }
    
    // This function is called every time the camera frame is updated.
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let arView = self.arView else {
            return
        }
        
        guard let destinationPoiName = self.destinationPoiName else {
            print("Error: destinationPoiName es nil.")
            return
        }
        
        updateArrowPositionAndDirection()
        showPointDebug()
        updateMovementPois(arView: arView, destinationPoiName: destinationPoiName)
   
        guard let cameraDepth = self.arSceneHandler?.cameraDeph else {
            print("Error: cameraDeph es nil.")
            return
        }
 
        modelManager.updateModelsBasedOnDistance(arView: arView, cameraDepth: cameraDepth)
        arSceneHandler?.handleFrameUpdate(frame: frame)
    }
    
    func setHasToReset(hasToRefresh: Bool){
        self.hasToRefresh = hasToRefresh
    }
    
    func showPointDebug(){
        if !self.isDebugEnabled{
            self.showPointTarget()
        }else{
            
            
            guard let arView = arView else { return }
            
            // Search anchor
            let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
                let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
                newAnchor.name = "fixedPOIAnchor"
                arView.scene.addAnchor(newAnchor)
                return newAnchor
            }()
            
            fixedPOIAnchor.children.filter { $0.name.starts(with: "point_") }
                .forEach { $0.removeFromParent() }
        }
    }
    
    func arePointsDifferent(_ oldPoints: [[String: Any]], _ newPoints: [[String: Any]]) -> Bool {
        guard oldPoints.count == newPoints.count else { return true }
        
        for (index, oldPoint) in oldPoints.enumerated() {
            let newPoint = newPoints[index]
            
            if let oldX = oldPoint["x"] as? Double, let newX = newPoint["x"] as? Double,
               let oldY = oldPoint["y"] as? Double, let newY = newPoint["y"] as? Double,
               let oldFloorIdentifier = oldPoint["floorIdentifier"] as? Int64, let newFloorIdentifier = newPoint["floorIdentifier"] as? Int64 {
                
                if oldX != newX || oldY != newY || oldFloorIdentifier != newFloorIdentifier {
                    return true
                }
            } else {
                return true // Return true if any key is missing or invalid
            }
        }
        
        return false
    }
    
    
    func handlePointUpdate(_ points: Any?) {
        if let newPointsList = points as? [[String: Any]] {
            
            // Check if the new list of points is different from the current one
            if arePointsDifferent(self.pointsList, newPointsList) {
                self.pointsList = newPointsList
            }
        } else {
            print("Invalid data format in userInfo")
        }
    }

        
    
    func setArrowDistance(arrowDistance: Double){
        self.arrowDistance = arrowDistance
    }
    
    func setDestinationPoi(destinationPoiName: String){
        self.destinationPoiName = destinationPoiName       
    }
     
    func initArrowToRoute(_ points: Any?){
        if let staticRoute = points as? [[String: Any]] {
            handlePointUpdate(staticRoute)
            updatePointsList()
        }

    }
    
    func calculateAndSetTargetPoint() {
        guard let arView = arView else { return }

        // Get the current camera position
        let cameraPosition = SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z)

        // We use a while loop to remove points without skipping any index
        var i = 0
        while i < storedTransformedPositions.count {
            
            // Calculate the distance between the camera and the point
            let distanceToCamera = simd_distance(cameraPosition, SIMD2<Float>(self.storedTransformedPositions[i].x, self.storedTransformedPositions[i].z))
            
            // If the distance is less than the threshold
            if distanceToCamera < Float(arrowDistance) {
                print("Eliminando punto en índice \(i) con distancia \(distanceToCamera)")
                
                // Call setTarget Coordinates before removing the point
                if i + 1 < storedTransformedPositions.count {
                    setTargetCoordinates(x: storedTransformedPositions[i + 1].x, z: storedTransformedPositions[i + 1].z)
                }

                // Reomve point
                storedTransformedPositions.remove(at: i)
            } else {
                // We only increment the index if we do not remove the point
                i += 1
            }
        }
    }

    
    
    func updateArrowPositionAndDirection() {
        guard let arView = arView, let arrowAnchor = arrowAnchor else { return }

        // Get camera position
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        // Calculate a fixed position in front of the camera
        let distanceInFrontOfCamera: Float = 0.5
        let forwardDirection = cameraTransform.matrix.columns.2
        let forwardVector = SIMD3<Float>(forwardDirection.x, forwardDirection.y, forwardDirection.z) * distanceInFrontOfCamera
        let targetPosition = cameraPosition - forwardVector
        
        // Position smoothing
        var smoothingFactor: Float = 0.2 // Adjust this value to control the level of smoothness
        if (self.hasToRefresh){
            smoothingFactor = 0.20
        }
        arrowAnchor.position = arrowAnchor.position + (targetPosition - arrowAnchor.position) * smoothingFactor

        calculateAndSetTargetPoint()

        if !isDebugEnabled {
            showPointTarget()
        }

        if targetX != 0 && targetZ != 0 {
                // Calculate the angle to the target
                let arrowPosition = arrowAnchor.position
                let targetVector = SIMD2<Float>(Float(targetX) - arrowPosition.x, Float(targetZ) - arrowPosition.z)
                var angleToTarget = atan2(-targetVector.y, targetVector.x)

                angleToTarget -= .pi / 2
                if let arrowEntity = arrowAnchor.children.first {
                    // Create the necessary rotation
                    let targetRotation = simd_quatf(angle: angleToTarget, axis: SIMD3<Float>(0, 1, 0))                    
                    //Rotational smoothing
                    arrowEntity.orientation = simd_slerp(arrowEntity.orientation, targetRotation, smoothingFactor)
                }
            }
    }

    
    
    func setupFixedAnchor() {
        guard let arView = arView else { return }
        
        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"
        
        arView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
    }
}
