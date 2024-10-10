import ARKit
import RealityKit
import CoreLocation

class Coordinator: NSObject, ARSessionDelegate {
    var locationManager: LocationManager
    var arrowAnchor: AnchorEntity?
    var fixedAnchor: AnchorEntity?
    var arView: ARView?    
    var yawLabel: UILabel?
    
    var didUpdatePOIs = false
    var locationUpdated = false
    var didUpdatePath = false
    
    var targetX = 0.0
    var targetZ = 0.0
    var targetFloorIdentifier = 0
    
    var pointsList: [[String: Any]] = []
    var storedTransformedPositions: [SIMD3<Float>] = []

 
      
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    // Esta función se llama en cada actualización del frame de la cámara
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
         // Obtener el yaw respecto al norte
         if let yaw = getCameraYawRespectToNorth() {
             let yawDegrees = yaw * (180.0 / .pi)
             // Actualizar el valor del label en la interfaz de usuario
            /* DispatchQueue.main.async {
                 self.yawLabel?.text = String(format: "Yaw: %.2f°", yawDegrees)
             }*/
         }
        updateArrowPositionAndDirection()
       
        
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

        
    func handlePointUpdate(_ notification: Notification) {
        if let userInfo = notification.userInfo, let newPointsList = userInfo["pointsList"] as? [[String: Any]] {
            
            // Verificar si la nueva lista de puntos es diferente a la actual
            if arePointsDifferent(self.pointsList, newPointsList) {
                self.pointsList = newPointsList
            }
        } else {
            print("Invalid data format in userInfo")
        }
    }

    
    func handleLocationUpdate(_ notification: Notification) {
        
            if let userInfo = notification.userInfo,
               let xSitum = userInfo["xSitum"] as? Double,
               let ySitum = userInfo["ySitum"] as? Double,
               let yawSitum = userInfo["yawSitum"] as? Double,
               let floorIdentifier = userInfo["floorIdentifier"] as? Double {
                
                // Llama al método que actualiza la ubicación en la escena
                updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifier)
            }
           
            else {
                print("Datos inválidos recibidos en la notificación: \(String(describing: notification.userInfo))")
            }
        }
    func calculateAndSetTargetPoint(){
        
        var targetPointSet = false
        guard let arView = arView else { return  }
        
        //Busca el ancla y la crea si no existe
        let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity ?? {
            let newAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0))
            newAnchor.name = "fixedPOIAnchor"
            arView.scene.addAnchor(newAnchor)
            return newAnchor
        }()
        
        // Eliminar el punto de la ruta
        fixedPOIAnchor.children.filter { $0.name.starts(with: "point_")}
            .forEach { $0.removeFromParent() }
        
        
        for (index, point) in self.storedTransformedPositions.enumerated() {
            //Calculo la distancia entre la camara y los puntos de la ruta ya transformados
            let distanceToCamera = simd_distance(SIMD2<Float>(arView.cameraTransform.translation.x, arView.cameraTransform.translation.z),
                                                 SIMD2<Float>(point.x, point.z))
            
            if distanceToCamera >= 5.0 && !targetPointSet {
                setTargetCoordinates(point.x, point.z)
                
                var poiEntity:ModelEntity
                poiEntity = createSphereEntity(radius: 0.35, color: .blue, transparency: 0.75) // Marcar el target
                poiEntity.position = point
                poiEntity.name = "point_\(index)"
                       
                fixedPOIAnchor.addChild(poiEntity)
                targetPointSet = true
                
            }
        }
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
        
        // Obtener la posición de la cámara
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        // Calcular una posición fija en frente de la cámara
        let distanceInFrontOfCamera: Float = 1.0 // Define la distancia fija frente a la cámara
        let forwardDirection = cameraTransform.matrix.columns.2 // Vector hacia adelante de la cámara

        // Calcular la nueva posición de la flecha
        let forwardVector = SIMD3<Float>(forwardDirection.x, forwardDirection.y, forwardDirection.z) * distanceInFrontOfCamera
        let arrowPosition = cameraPosition - forwardVector
        
        self.calculateAndSetTargetPoint()
        
        if self.targetX != 0 && self.targetZ != 0 {
            if let yawPoint = calculateAngleToTarget(){
            
                if let arrowEntity = arrowAnchor.children.first {
                    
                    if yawPoint != 0.0 {
                        // Primero aplicar la rotación de pi/2 alrededor del eje X (ajuste de orientación)
                        let rotationX = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))
                        // Luego aplicar la rotación alrededor del eje Y basada en yawPoint
                        let rotationY = simd_quatf(angle: yawPoint, axis: SIMD3<Float>(0, -1, 0))
                        // Multiplicar los cuaterniones, primero rotación en X y luego en Y
                        let combinedRotation = rotationY * rotationX
                        arrowEntity.orientation = combinedRotation
                    }
                }
                
            }
        }
        
        // Actualizar la posición del ancla de la flecha
        arrowAnchor.position = SIMD3<Float>(arrowPosition.x, -0.5 , arrowPosition.z)
    }
    

    func setupFixedAnchor() {
        guard let arView = arView else { return }

        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        arView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
    }
    
            
    func setTargetCoordinates(_ x: Float, _ z: Float ){
            
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
                
        
        // Aplico la transformación a todos los puntos de la ruta
            for (index, point) in self.pointsList.enumerated() {
                if let xPoint = point["x"] as? Double, let yPoint = point["y"] as? Double {
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
        }
        
      
    }

    
    func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double, floorIdentifier: Double) {
         
            guard !locationUpdated else { return }
           
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
            locationUpdated = true
        }
    
    func updatePOIs(poisMap: [String: Any], width: Double) {
        guard !didUpdatePOIs, let arView = arView, let initialLocation = locationManager.initialLocation else { return }

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
        guard let poisList = poisMap["pois"] as? [[String: Any]] else {
            print("Error: No se encontró la clave 'pois' en el mapa de POIs")
            return
        }

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
                let poiEntity = createSphereEntity(radius: 0.5, color: .green, transparency: 1.0)
                poiEntity.position = transformedPosition
                poiEntity.name = "poi_\(index)"

                let textEntity = createTextEntity(text: name, position: transformedPosition)
                textEntity.name = "text_\(index)"

                // Añadir ambos al ancla
                fixedPOIAnchor.addChild(poiEntity)
                fixedPOIAnchor.addChild(textEntity)
            }
        }
        self.updatePointsList()
        didUpdatePOIs = true
    }


    func resetFlags() {
        didUpdatePOIs = false
        locationUpdated = false
        didUpdatePath = false
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

    func createSphereEntity(radius: Float, color: UIColor, transparency: Float) -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: radius)

        // Descomponer el color en componentes de tono, saturación y brillo
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        // Reducir la saturación del color
        let desaturatedColor = UIColor(hue: hue, saturation: saturation * 0.5, brightness: brightness, alpha: alpha * CGFloat(transparency))

        // Crear el material con transparencia y color desaturado
        let material = SimpleMaterial(color: desaturatedColor, isMetallic: false)

        let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])

        return sphereEntity
    }



    func createTextEntity(text: String, position: SIMD3<Float>) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.02,
            font: .systemFont(ofSize: 1.3),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let material = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: mesh, materials: [material])

        textEntity.scale = SIMD3<Float>(0.3, 0.3, 0.3)
        textEntity.position = SIMD3<Float>(position.x, position.y + 0.5, position.z)

        return textEntity
    }

    func updateTextOrientation() {
            guard let arView = arView else { return }

            if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
                for child in fixedPOIAnchor.children {
                    if let textEntity = child as? ModelEntity, textEntity.name.starts(with: "text_") {
                        let cameraTransform = arView.cameraTransform
                        let cameraPosition = cameraTransform.translation

                        textEntity.look(at: cameraPosition, from: textEntity.position, relativeTo: nil)
                        textEntity.orientation = simd_mul(
                            textEntity.orientation,
                            simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                        )
                    }
                }
            }
        }
    }
