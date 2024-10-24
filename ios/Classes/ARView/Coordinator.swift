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
    

    var didUpdatePath = false
    
    var targetX = 0.0
    var targetZ = 0.0
    var targetFloorIdentifier = 0
    
    var arrowDistance = 5.0
    
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
            // Actualizar el valor del label en la interfaz de usuario
            /* DispatchQueue.main.async {
             self.yawLabel?.text = String(format: "Yaw: %.2f°", yawDegrees)
             }*/
        }
        
        updateArrowPositionAndDirection()
        updateTextOrientation(arView: arView)
        rotateIconPoi(arView: arView)
        arSceneHandler?.handleFrameUpdate(frame: frame) // Reenviar al ARSceneHandler
        
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
    
    func handlePoisUpdated(poisMap: [String: Any]){
        poisStored = poisMap
        self.updatePOIs()
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
    
    
    func handleLocationUpdate(location: SITLocation) {
        
        // Verifica si las coordenadas son opcionales y convierte floorIdentifier de String a Double
        if let cartesianCoordinate = location.position.cartesianCoordinate,
           let floorIdentifierAsDouble = Double(location.position.floorIdentifier) {
            let xSitum = cartesianCoordinate.x
            let ySitum = cartesianCoordinate.y
            let yawSitum = Double(location.cartesianBearing.radians()) // Asegúrate de usar la propiedad correcta para convertir SITAngle a Double
            
            // Llama al método que actualiza la ubicación en la escena
            updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifierAsDouble)
            
        } else {
            print("Datos inválidos recibidos en la notificación o conversión de floorIdentifier fallida: \(location)")
        }
    }
    
    func setArrowDistance(arrowDistance: Double){
        self.arrowDistance = arrowDistance
    }
    
    
    func calculateDistanceToCamera(x: Float, z: Float) -> Float{
        
        guard let arView = arView else { return  0.0 }
        let distanceToCamera = simd_distance(SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z),
                                             SIMD2<Float>(x, z))
        return distanceToCamera
        
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
            
            // Si la distancia es menor que el umbral, eliminamos el punto
            if distanceToCamera < Float(arrowDistance) {
                print("Eliminando punto en índice \(i) con distancia \(distanceToCamera)")
                storedTransformedPositions.remove(at: i)
                setTargetCoordinates(x: storedTransformedPositions[i].x, z: storedTransformedPositions[i].z)
            } else {
                // Solo incrementamos el índice si no eliminamos el punto
                i += 1
            }
        }
        
    }
    
    
    
    func showPointTarget(){
        
        guard let arView = arView else { return }
        
        // Buscar el ancla y crear si no existe
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Eliminar el punto de la ruta existente
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_") }
            .forEach { $0.removeFromParent() }
        
        // Crear la entidad de la esfera para marcar el punto objetivo
        let poiEntity = createSphereEntity(radius: 0.35, color: .blue, transparency: 0.75)
        let targetPosition = SIMD3<Float>(Float(self.targetX), -0.5, Float(self.targetZ))  // Establecer y como -0.5 o cualquier valor apropiado
        poiEntity.position = targetPosition
        poiEntity.name = "point_" // Dar un nombre único a la esfera
        
        // Agregar la esfera al ancla
        fixedPOIAnchor.addChild(poiEntity)
        
    }
    
    
    func calculateAngleToTarget() -> Float? {
        
        guard let arView = arView else { return nil }
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        
        // Crear el vector desde la cámara hasta el objetivo en el plano XZ
        let directionToTarget = SIMD2<Float>(Float(self.targetX) - cameraPosition.x, Float(self.targetZ) - cameraPosition.z)
        let normalizedDirectionToTarget = normalize(directionToTarget)
        
        // Calcular el ángulo hacia el objetivo
        let angleToTarget = atan2(normalizedDirectionToTarget.y, normalizedDirectionToTarget.x)
        let angleDifference = angleToTarget + .pi/2.0
        
        return angleDifference
    }
    
    
    func updateArrowPositionAndDirection() {
        guard let arView = arView, let arrowAnchor = arrowAnchor else { return }
        
        // Obtener la posición y orientación de la cámara
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        // Definir la posición fija relativa a la cámara
        let offsetFromCamera: SIMD3<Float> = SIMD3<Float>(0, 0.0, -2.0) // Ajusta el offset para la posición deseada

        // Calcular la posición de la flecha en coordenadas del mundo
        let cameraMatrix = cameraTransform.matrix
        let offsetInWorldSpace = cameraMatrix * SIMD4<Float>(offsetFromCamera.x, offsetFromCamera.y, offsetFromCamera.z, 1.0)
        let arrowPosition = cameraPosition + SIMD3<Float>(offsetInWorldSpace.x, offsetInWorldSpace.y, offsetInWorldSpace.z)

        // Actualizar la posición del ancla de la flecha para que esté fija en la cámara
        arrowAnchor.position = arrowPosition
        
        // Mantener la orientación de la flecha fija
        if let arrowEntity = arrowAnchor.children.first {
            // Establecer la orientación para que siempre apunte hacia adelante de la cámara
            let fixedRotation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
            arrowEntity.orientation = fixedRotation
        }
    }
    
    
    func setupFixedAnchor() {
        guard let arView = arView else { return }
        
        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"
        
        arView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
    }
    
    
    func setTargetCoordinates(x: Float, z: Float ){
        
        self.targetX = Double(x)
        self.targetZ = Double(z)
        //self.targetFloorIdentifier = Int(floorIdentifier)
        
        print("x_target: \(self.targetX), z_target: \(self.targetZ)")//, floorIdentifier: \(self.targetFloorIdentifier)")
        
    }
    
    func updatePointsList() {
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Buscar o crear el ancla 'fixedPOIAnchor'
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Eliminar todos los puntos de la ruta
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_")}
            .forEach { $0.removeFromParent() }
        
        
        self.storedTransformedPositions.removeAll()
        // Aplico la transformación a todos los puntos de la ruta
        for (index, point) in self.pointsList.enumerated() {
            if let cartesianCoordinate = point["cartesianCoordinate"] as? [String: Double],
               let xPoint = cartesianCoordinate["x"],
               let yPoint = cartesianCoordinate["y"]{
                
                let transformedPosition = generateARKitPosition(
                    x: Float(xPoint),
                    y: Float(yPoint),
                    currentLocation: initialLocation,
                    arView: arView
                )
                self.storedTransformedPositions.append(transformedPosition)
                
            } else {
                print("Invalid point data: \(point)")
            }
            
            setTargetCoordinates(x: self.storedTransformedPositions[0].x, z: self.storedTransformedPositions[0].z)
        }
        
        
    }
    
    
    func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double, floorIdentifier: Double) {
        
        let newLocation = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: ySitum, longitude: xSitum),
            altitude: floorIdentifier,
            horizontalAccuracy: kCLLocationAccuracyBest,
            verticalAccuracy: kCLLocationAccuracyBest,
            course: yawSitum,
            speed: 0,
            timestamp: Date()
        )
        
        locationManager.initialLocation = newLocation
    }
    
    func updatePOIs() {
      
        guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
        
        // Buscar o crear el ancla 'fixedPOIAnchor'
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
               
        // Eliminar todos los POIs y textos anteriores
        fixedPOIAnchor.children.filter { $0.name.starts(with: "poi_") || $0.name.starts(with: "text_") }
            .forEach { $0.removeFromParent() }
        
        // Obtener lista de POIs
        guard let poisList = self.poisStored["pois"] as? [[String: Any]] else {
            print("Error: No se encontró la clave 'pois' en el mapa de POIs")
            return
        }
        
        print("pois list!:  ", poisList)
        
        // Añadir los nuevos POIs
        for (index, poi) in poisList.enumerated() {
            if let position = poi["position"] as? [String: Any],
               let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
               let floorIdentifier = position["floorIdentifier"] as? String,
               let x = cartesianCoordinate["x"],
               let y = cartesianCoordinate["y"],
               let name = poi["name"] as? String,
               floorIdentifier == String(Int(initialLocation.altitude)) {
                
                let transformedPosition = generateARKitPosition(x: Float(x), y: Float(y), currentLocation: initialLocation, arView: arView)
                
                // Crear POI y texto
                //let poiEntity = createSphereEntity(radius: 0.5, color: .green, transparency: 1.0)
            
                let iconUrlString = poi["iconUrl"] as? String ?? ""
                // Asegúrate de usar la URL correcta
                guard let iconUrl = URL(string: iconUrlString) else {
                    print("Error: URL no válida para el icono del POI: \(name)")
                    continue
                }
                
                createDiskEntityWithImageFromURL(radius: 0.8, thickness: 0.2, url: iconUrl) { poiEntity in
                        guard let poiEntity = poiEntity else {
                            print("Error: No se pudo crear el disco para el POI")
                            return
                        }
                        poiEntity.position = transformedPosition
                        poiEntity.name = "poi_\(index)"
                        
                    let textEntity = createTextEntity(text: name, position: transformedPosition, arView: arView)
                        textEntity.name = "text_\(index)"
                        
                        // Añadir ambos al ancla
                        fixedPOIAnchor.addChild(poiEntity)
                        fixedPOIAnchor.addChild(textEntity)
                  
                    }
                
                                
            }
        }
        self.updatePointsList()
    }
    
   
    func getCameraYawRespectToNorth() -> Float? {
        // Obtener el yaw original de la cámara
        guard let yaw = arView?.session.currentFrame?.camera.eulerAngles.y else {
            return nil
        }
        
        // Ajustar el yaw para que siga tus necesidades:
        // 0° será frente, +90° derecha, -90° izquierda, y 180° atrás
        let adjustedYaw = -yaw // Cambiamos el signo del yaw para invertir izquierda y derecha        
        // Asegurarnos de que el valor ajustado esté dentro del rango [-π, π]
        let normalizedYaw = fmod(adjustedYaw + .pi, 2 * .pi) - .pi
        
        return normalizedYaw
        
    }
    
    func generateARKitPosition(x: Float, y: Float, currentLocation: CLLocation, arView: ARView) -> SIMD3<Float> {
        
        // Obtener el yaw de la cámara respecto al norte
        guard let cameraBearing = getCameraYawRespectToNorth() else {
            return SIMD3<Float>(0, 0, 0) // Retorna un valor por defecto si no se pudo obtener el yaw
        }
        
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        
        let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0.0, 1.0, 0.0))
        
        let course = -currentLocation.course // Cambiamos el signo del yaw para invertir izquierda y derecha
        
        // Asegurarnos de que el valor ajustado esté dentro del rango [-π, π]
        let courseNormalized = fmod(course + .pi, 2 * .pi) - .pi
        
        let situmBearingDegrees = courseNormalized * (180.0 / .pi) + 90.0
        let situmBearingInRadians = Float(situmBearingDegrees) * (.pi / 180.0)
        let situmBearingMinusRotation = simd_quatf(angle: (situmBearingInRadians), axis: SIMD3<Float>(0.0, -1.0, 0.0))
        
        let relativePoiPosition = SIMD3<Float>(
            x - Float(currentLocation.coordinate.longitude),
            0,
            y - Float(currentLocation.coordinate.latitude)
        )
        
        let positionsMinusSitumRotated = situmBearingMinusRotation.act(relativePoiPosition)
        
        // Rotar la posición ajustada basándose en la rotación horizontal de la cámara
        var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
        
        // Trasladar la posición al sistema de la cámara
        positionRotatedAndTranslatedToCamera.x = cameraPosition.x + positionRotatedAndTranslatedToCamera.x
        positionRotatedAndTranslatedToCamera.z = cameraPosition.z - positionRotatedAndTranslatedToCamera.z
        positionRotatedAndTranslatedToCamera.y = -1
        
        
        return positionRotatedAndTranslatedToCamera
    }
    
}
