import ARKit
import RealityKit
import CoreLocation

class Coordinator: NSObject, ARSessionDelegate {
    var locationManager: LocationManager
    var arrowAndTextAnchor: AnchorEntity?
    var fixedAnchor: AnchorEntity?
    weak var arView: ARView?
    
    var didUpdatePOIs = false
    var locationUpdated = false
    
    init(locationManager: LocationManager) {
        self.locationManager = locationManager
    }
    
    func handleLocationUpdate(_ notification: Notification) {
            print("Notificación de ubicación actualizada recibida")
            
            if let userInfo = notification.userInfo,
               let xSitum = userInfo["xSitum"] as? Double,
               let ySitum = userInfo["ySitum"] as? Double,
               let yawSitum = userInfo["yawSitum"] as? Double,
               let floorIdentifier = userInfo["floorIdentifier"] as? Double {
                
                // Llama al método que actualiza la ubicación en la escena
                updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifier)
            } else {
                print("Datos inválidos recibidos en la notificación: \(String(describing: notification.userInfo))")
            }
        }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        updateArrowPositionAndDirection()
    }

    func updateArrowPositionAndDirection() {
        guard let arView = arView, let arrowAndTextAnchor = arrowAndTextAnchor else { return }
        
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation

        let distance: Float = 2.0
        let forwardVector = -SIMD3<Float>(cameraTransform.matrix.columns.2.x,
                                          cameraTransform.matrix.columns.2.y,
                                          cameraTransform.matrix.columns.2.z)

        let forwardPosition = cameraPosition + forwardVector * distance
        arrowAndTextAnchor.position = forwardPosition

        if let heading = locationManager.heading {
            let headingRadians = Float(heading.trueHeading + 90) * .pi / 180
            let northOrientation = simd_quatf(angle: headingRadians, axis: [0, -1, 0])
            if let arrowEntity = arrowAndTextAnchor.children.first {
                arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * northOrientation
            }
        }
    }

    func setupFixedAnchor() {
        guard let arView = arView else { return }

        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        do {
            let robotEntity = try ModelEntity.load(named: "Animated_Dragon_Three_Motion_Loops.usdz")
            robotEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
            robotEntity.position = SIMD3<Float>(-1.0, -10.0, -2.0)

            let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            robotEntity.orientation = rotation

            if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }
            
            fixedAnchor.addChild(robotEntity)
        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }

        arView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
    }
    
    func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double, floorIdentifier: Double) {
            // Comprobar si la ubicación ya ha sido actualizada
            guard !locationUpdated else { return }
            print("XSITUM:  ", xSitum)
            print("YSITUM:  ", ySitum)
            print("YAWSITUM:  ", yawSitum)
            print("FLOORIDENTIFIER:  ", floorIdentifier)
            
            // Aquí se actualiza la posición solo la primera vez
            print("Actualizando la ubicación solo una vez")
            let locationPosition = SIMD4<Float>(Float(xSitum), Float(ySitum), Float(yawSitum), Float(floorIdentifier))

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

            for (index, poi) in poisList.enumerated() {
                if let position = poi["position"] as? [String: Any],
                   let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
                   let floorIdentifier = position["floorIdentifier"] as? String,
                   let x = cartesianCoordinate["x"],
                   let y = cartesianCoordinate["y"],
                   let name = poi["name"] as? String,
                   floorIdentifier == String(Int(initialLocation.altitude)) {

                    let transformedPosition = generateARKitPosition(x: Float(x), y: Float(width - y), currentLocation: initialLocation, arView: arView)

                    let poiEntity = createSphereEntity(radius: 1, color: .green)
                    poiEntity.position = transformedPosition
                    poiEntity.name = "poi_\(index)"

                    let textEntity = createTextEntity(text: name, position: transformedPosition)
                    textEntity.name = "text_\(index)"

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
    }

    func generateARKitPosition(x: Float, y: Float, currentLocation: CLLocation, arView: ARView) -> SIMD3<Float> {
        let cameraTransform = arView.cameraTransform
        let cameraPosition = cameraTransform.translation
        let cameraOrientation = cameraTransform.rotation

        let forwardVector = cameraOrientation.act(SIMD3<Float>(0, 0, -1))
        let cameraBearing = atan2(forwardVector.x, forwardVector.z)

        let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0, 1, 0))

        let situmBearingDegrees = currentLocation.course
        guard situmBearingDegrees >= 0 else {
            return SIMD3<Float>(0, 0, 0)
        }
        let situmBearing = Float(situmBearingDegrees) + 90.0
        let situmBearingMinusRotation = simd_quatf(angle: situmBearing * .pi / 180.0, axis: SIMD3<Float>(0, -1, 0))

        let relativePoiPosition = SIMD3<Float>(
            x - Float(currentLocation.coordinate.longitude),
            0,
            y - Float(currentLocation.coordinate.latitude)
        )

        let positionsMinusSitumRotated = situmBearingMinusRotation.act(relativePoiPosition)
        var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
        positionRotatedAndTranslatedToCamera += cameraPosition
        positionRotatedAndTranslatedToCamera.y = 0

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

        textEntity.scale = SIMD3<Float>(0.5, 0.5, 0.5)
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
