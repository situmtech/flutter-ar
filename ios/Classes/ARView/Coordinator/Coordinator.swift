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
    
    
    init(locationManager: LocationManager) {        
        self.locationManager = locationManager
    }
    
    // Esta función se llama en cada actualización del frame de la cámara
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
       
        guard let arView = self.arView else {
            return
        }
        
        // Obtener el yaw respecto al norte
        if let yaw = getCameraYawRespectToNorth() {
            let yawDegrees = yaw * (180.0 / .pi)
        }
        
        updateArrowPositionAndDirection()
        showPointDebug()
        updatePOIOrientationToCamera(arView: arView)
        arSceneHandler?.handleFrameUpdate(frame: frame) // Reenviar al ARSceneHandler
        
    }
    
    func setHasToReset(hasToRefresh: Bool){
        self.hasToRefresh = hasToRefresh
    }
    
    func showPointDebug(){
        if !self.isDebugEnabled{
            self.showPointTarget()
        }else{
            
            
            guard let arView = arView else { return }
            
            // Buscar el ancla y crear si no existe
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
            
            // Verificar si la nueva lista de puntos es diferente a la actual
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
     
    func initArrowToRoute(_ points: Any?){
        if let staticRoute = points as? [[String: Any]] {
            handlePointUpdate(staticRoute)
            updatePointsList()
        }

    }
    
    func calculateAndSetTargetPoint() {
        guard let arView = arView else { return }

        // Obtener la posición actual de la cámara
        let cameraPosition = SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z)

        // Usamos un bucle while para eliminar puntos sin saltar ningún índice
        var i = 0
        while i < storedTransformedPositions.count {
            
            // Calcular la distancia entre la cámara y el punto
            let distanceToCamera = simd_distance(cameraPosition, SIMD2<Float>(self.storedTransformedPositions[i].x, self.storedTransformedPositions[i].z))
            
            // Si la distancia es menor que el umbral
            if distanceToCamera < Float(arrowDistance) {
                print("Eliminando punto en índice \(i) con distancia \(distanceToCamera)")
                
                // Llamar a setTargetCoordinates antes de eliminar el punto
                if i + 1 < storedTransformedPositions.count {
                    setTargetCoordinates(x: storedTransformedPositions[i + 1].x, z: storedTransformedPositions[i + 1].z)
                }

                // Eliminar el punto
                storedTransformedPositions.remove(at: i)
            } else {
                // Solo incrementamos el índice si no eliminamos el punto
                i += 1
            }
        }
    }

    
    
    func updateArrowPositionAndDirection() {
        guard let arView = arView, let arrowAnchor = arrowAnchor else { return }

        // Obtener la posición de la cámara
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        // Calcular una posición fija en frente de la cámara
        let distanceInFrontOfCamera: Float = 0.5
        let forwardDirection = cameraTransform.matrix.columns.2
        let forwardVector = SIMD3<Float>(forwardDirection.x, forwardDirection.y, forwardDirection.z) * distanceInFrontOfCamera
        let targetPosition = cameraPosition - forwardVector
        
        // Suavizado de posición4
        var smoothingFactor: Float = 0.2 // Ajusta este valor para controlar el nivel de suavidad
        print("has to reset:    ", self.hasToRefresh)
        if (self.hasToRefresh){
            smoothingFactor = 0.10
        }
        arrowAnchor.position = arrowAnchor.position + (targetPosition - arrowAnchor.position) * smoothingFactor

        calculateAndSetTargetPoint()

        if !isDebugEnabled {
            showPointTarget()
        }

        if targetX != 0 && targetZ != 0 {
                // Calcular el ángulo hacia el objetivo
                let arrowPosition = arrowAnchor.position
                let targetVector = SIMD2<Float>(Float(targetX) - arrowPosition.x, Float(targetZ) - arrowPosition.z)
                var angleToTarget = atan2(-targetVector.y, targetVector.x)

                angleToTarget -= .pi / 2
                if let arrowEntity = arrowAnchor.children.first {
                    print("TARGET X AND Z: ", targetX, "    ", targetZ)
                    
                    // Crear la rotación necesaria
                    let targetRotation = simd_quatf(angle: angleToTarget, axis: SIMD3<Float>(0, 1, 0))
                    
                    // Suavizado de rotación
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
