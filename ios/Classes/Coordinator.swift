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
    
    var width = 0.0
    var targetX = 0.0
    var targetY = 0.0
 
      
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    // Esta función se llama en cada actualización del frame de la cámara
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
         // Obtener el yaw respecto al norte
         if let yaw = getCameraYawRespectToNorth() {
             // Convertir el yaw de radianes a grados
             let yawDegrees = yaw * (180.0 / .pi)
             
             // Actualizar el valor del label en la interfaz de usuario
             DispatchQueue.main.async {
                 self.yawLabel?.text = String(format: "Yaw: %.2f°", yawDegrees)
             }
         }
     }
    
    
    func handlePointUpdate(_ notification: Notification) {
        // Verificar que userInfo no sea nil
        
        if let userInfo = notification.userInfo {
            // Verificar que userInfo contenga una lista de diccionarios en el formato correcto
            if let pointsList = userInfo["pointsList"] as? [[String: Any]] {
                updatePointsList(pointsList: pointsList)
            } else {
                print("Invalid data format in userInfo")
            }
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

   /* func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateArrowPositionAndDirection()
    }*/
    
    func setWidth(_width: Double){
        width = _width
    }

    func updateArrowPositionAndDirection() {
       /* guard let arView = arView, let arrowAnchor = arrowAnchor else { return }
        
        // Obtener la posición de la cámara
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        let forwardVector: SIMD3<Float>
        
        if targetX == 0 && targetY == 0 {
            print("TargetX y targetY = cero")
            // Si targetX y targetY son cero, apuntar en la dirección hacia adelante de la cámara
            forwardVector = -SIMD3<Float>(cameraTransform.matrix.columns.2.x,
                                          cameraTransform.matrix.columns.2.y,
                                          cameraTransform.matrix.columns.2.z)
        } else {
            print("TargetX y targetY distinto de cero  ", targetX)
            print("TargetX y targetY distinto de cero  ", Float(cameraPosition.y))
            print("TargetX y targetY distinto de cero  ", Float(targetY))
            // Si se ha especificado un objetivo (targetX, targetY), calcular la dirección hacia él
            let targetPosition = SIMD3<Float>(Float(targetX), Float(cameraPosition.y), Float(targetY)) // Mantener la misma altura (y) que la cámara
            forwardVector = normalize(targetPosition - cameraPosition)
        }

        // Establecer una distancia fija (por ejemplo, 2 metros) desde la cámara
        let distance: Float = 2.0
        let forwardPosition = cameraPosition + forwardVector * distance

        // Actualizar la posición del ancla de la flecha
        arrowAnchor.position = forwardPosition

        // Calcular la rotación hacia el objetivo o hacia adelante
        let angleToTarget = atan2(forwardVector.x, forwardVector.z)
        let rotationToTarget = simd_quatf(angle: angleToTarget, axis: [0, 1, 0])

        // Aplicar la rotación a la flecha, ajustando para que apunte hacia adelante
        if let arrowEntity = arrowAnchor.children.first {
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * rotationToTarget
        }*/
    }




    func setupFixedAnchor() {
        guard let arView = arView else { return }

        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        /*do {
            let robotEntity = try ModelEntity.load(named: "Animated_Dragon_Three_Motion_Loops.usdz")
            robotEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
            robotEntity.position = SIMD3<Float>(-1.0, -10.0, -8.0)

            let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            robotEntity.orientation = rotation

            if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }
            
            fixedAnchor.addChild(robotEntity)
        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }*/

        arView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
    }
    
    func updatePointsList(pointsList: [[String: Any]]){
        guard !didUpdatePath, let arView = arView, let initialLocation = locationManager.initialLocation else {
            print("ARView or initialLocation is nil")
            return
        }

        // Buscar el ancla existente
        if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
            
            // Eliminar todas las esferas anteriores
            fixedPOIAnchor.children.filter { $0.name.starts(with: "point_") }.forEach { $0.removeFromParent() }

            for (index, point) in pointsList.enumerated() {
                // Extraer el x y el y de cada punto
                if let xPoint = point["x"] as? Double, let yPoint = point["y"] as? Double {
                    
                    // Aplicar generateARKitPosition a cada punto
                    let transformedPosition = generateARKitPosition(
                        x: Float(xPoint),
                        y: Float(yPoint),
                        currentLocation: initialLocation,
                        arView: arView
                    )
                    
                    // Crear una nueva esfera
                    let poiEntity = createSphereEntity(radius: 0.15, color: .magenta)
                    poiEntity.position = transformedPosition
                    poiEntity.name = "point_\(index)" // Dar un nombre único a cada esfera

                    // Agregar la esfera al ancla
                    fixedPOIAnchor.addChild(poiEntity)
                } else {
                    print("Invalid point data: \(point)")
                }
            }
            
            didUpdatePath = true
        } else {
            print("No se encontró el ancla 'fixedPOIAnchor'")
        }
    }

    
    func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double, floorIdentifier: Double) {
            // Comprobar si la ubicación ya ha sido actualizada
            guard !locationUpdated else { return }
            print("XSITUM:  ", xSitum)
            print("YSITUM:  ", ySitum)
            print("YAWSITUM:  ", yawSitum)
            print("FLOORIDENTIFIER:  ", floorIdentifier)      
        

            let locationPosition = SIMD4<Float>(Float(xSitum), Float(ySitum), Float(yawSitum), Float(floorIdentifier))
            //let locationPosition = SIMD4<Float>(Float(152.5569763183594), Float(29.70142555236816), Float(36.68222045898438), Float(38718))


            // Simular la actualización de la ubicación inicial
            let newLocation = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: ySitum, longitude: xSitum),
                altitude: floorIdentifier,
                horizontalAccuracy: kCLLocationAccuracyBest,
                verticalAccuracy: kCLLocationAccuracyBest,
                course: yawSitum,
                speed: 0,
                timestamp: Date()
            )
            
            // Guardar la nueva ubicación en locationManager
            locationManager.initialLocation = newLocation

            // Marcar que la ubicación ha sido actualizada
            locationUpdated = true
        }


    func updatePOIs(poisMap: [String: Any], width: Double) {
        guard !didUpdatePOIs, let arView = arView, let initialLocation = locationManager.initialLocation else { return }

        if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
            fixedPOIAnchor.children.filter { $0.name.starts(with: "poi_") || $0.name.starts(with: "text_") }
                .forEach { $0.removeFromParent() }

            guard let poisList = poisMap["pois"] as? [[String: Any]] else {
                print("Error: No se encontró la clave 'pois' en el mapa de POIs")
                return
            }
            
            // Eliminar cualquier POI anterior (si existe)
            if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
                fixedPOIAnchor.children.filter { $0.name.starts(with: "poi_") || $0.name.starts(with: "text_") }
                    .forEach { $0.removeFromParent() }
            } else {
                // Crear un nuevo ancla fijo si no existe
                let fixedPOIAnchor = AnchorEntity(world: SIMD3<Float>(0, 0, 0)) // Puedes ajustar la posición inicial del ancla
                fixedPOIAnchor.name = "fixedPOIAnchor"
                arView.scene.addAnchor(fixedPOIAnchor)
            }

            guard let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity else {
                print("Error: No se pudo crear o encontrar el ancla 'fixedPOIAnchor'")
                return
            }



            for (index, poi) in poisList.enumerated() {
                if let position = poi["position"] as? [String: Any],
                   let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
                   let floorIdentifier = position["floorIdentifier"] as? String,
                   let x = cartesianCoordinate["x"],
                   let y = cartesianCoordinate["y"],
                   let name = poi["name"] as? String,
                   floorIdentifier == String(Int(initialLocation.altitude)) {
                   let transformedPosition = generateARKitPosition(x: Float(x), y: Float(y), currentLocation: initialLocation, arView: arView)

                    // Si el POI está muy lejos de la cámara, lo escalamos a cero o lo eliminamos.
                      
                   let poiEntity = createSphereEntity(radius: 0.5, color: .green)
                   poiEntity.position = transformedPosition
               
                   poiEntity.name = "poi_\(index)"

                   let textEntity = createTextEntity(text: name, position: transformedPosition)
                   textEntity.name = "text_\(index)"

                    print("POI:  ", name, "  ", transformedPosition.x, "  ",transformedPosition.z)
                    fixedPOIAnchor.addChild(poiEntity)
                    fixedPOIAnchor.addChild(textEntity)
                      
                   }
            }

            if !arView.scene.anchors.contains(where: { $0 as? AnchorEntity == fixedPOIAnchor }) {
                arView.scene.anchors.append(fixedPOIAnchor)
            }
        }

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
        guard let yaw = getCameraYawRespectToNorth() else {
            return SIMD3<Float>(0, 0, 0) // Retorna un valor por defecto si no se pudo obtener el yaw
        }
      
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        
        print("camera position:   ", cameraPosition.x," ", cameraPosition.y, "   ", cameraPosition.z )

        let cameraBearing = yaw
        print("yaw cameraBearing!!!!!!!!!!!!!!!!!!!!!!!!:   ", cameraBearing)
        let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0, 1, 0))

        let situmBearingDegrees = currentLocation.course * (180.0 / .pi)
        
        print("yaw situmBearingDegrees!!!!!!!!!!!!!!!!!!!!!!!!:   ", situmBearingDegrees)
     
        let situmBearing = Float(situmBearingDegrees + 90.0)
        
        
        let situmBearingMinusRotation = simd_quatf(angle: situmBearing * .pi / 180.0, axis: SIMD3<Float>(0, -1, 0))

        let relativePoiPosition = SIMD3<Float>(
            x - Float(currentLocation.coordinate.longitude),
            0,
            y - Float(currentLocation.coordinate.latitude)
        )

        
        let positionsMinusSitumRotated = situmBearingMinusRotation.act(relativePoiPosition)
               
        // Rotar la posición ajustada basándose en la rotación horizontal de la cámara
        var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
               
        // Trasladar la posición al sistema de la cámara
        //positionRotatedAndTranslatedToCamera += cameraPosition
        positionRotatedAndTranslatedToCamera.x = cameraPosition.x + positionRotatedAndTranslatedToCamera.x
        positionRotatedAndTranslatedToCamera.z = cameraPosition.z - positionRotatedAndTranslatedToCamera.z

        
                
        //positionRotatedAndTranslatedToCamera.z = -positionRotatedAndTranslatedToCamera.z
               
        // Establecer la altura en 0 (ajusta si es necesario)
        positionRotatedAndTranslatedToCamera.y = -1

        
        return positionRotatedAndTranslatedToCamera
    }

    func createSphereEntity(radius: Float, color: UIColor) -> ModelEntity {
        let sphereMesh = MeshResource.generateSphere(radius: radius)
        let material = SimpleMaterial(color: color, isMetallic: false)
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
