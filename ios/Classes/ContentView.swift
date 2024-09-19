import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import simd
import Combine  // Importar Combine para manejar las suscripciones


extension Notification.Name {
    static let resetCoordinatorFlags = Notification.Name("resetCoordinatorFlags")
}

// Clase LocationManager para manejar la ubicación
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var heading: CLHeading?
    @Published var initialLocation: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }
}

// Vista principal ContentView
@available(iOS 13.0, *)
struct ContentView: View {
    @ObservedObject private var locationManager = LocationManager()
    @State private var poisMap: [String: Any]
    @State private var width: Double = 0.0
    @State private var showAlert = false  // Estado para mostrar la alerta

    init(poisMap: [String: Any]) {
        _poisMap = State(initialValue: poisMap)
    }

    var body: some View {
        ARViewContainer(poisMap: $poisMap, locationManager: locationManager, width: width)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: .poisUpdated)) { notification in
                if let poisMap = notification.userInfo?["poisMap"] as? [String: Any] {
                    self.poisMap = poisMap
                }
                if let width = notification.userInfo?["width"] as? Double {
                    self.width = width
                } else {
                    print("Failed to cast POIs map. UserInfo: \(String(describing: notification.userInfo))")
                }
            }
            // Observa la notificación del botón presionado
            .onReceive(NotificationCenter.default.publisher(for: .buttonPressedNotification)) { _ in
                self.showAlert = true
                // Envía notificación para resetear flags
                NotificationCenter.default.post(name: .resetCoordinatorFlags, object: nil)
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Actualizando Vista AR"), dismissButton: .default(Text("OK")))
            }
    }
}


// Vista ARViewContainer
@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @Binding var poisMap: [String: Any]
    @ObservedObject var locationManager: LocationManager
    var width: Double

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configuración de ARKit
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        arView.session.run(configuration)

        let arrowAndTextAnchor = createArrowAndTextAnchor()
        arView.scene.anchors.append(arrowAndTextAnchor)
        
        context.coordinator.arrowAndTextAnchor = arrowAndTextAnchor
        context.coordinator.arView = arView
        
        context.coordinator.setupFixedAnchor()

        // Suscribirse a la notificación de ubicación actualizada
        NotificationCenter.default.addObserver(forName: .locationUpdated, object: nil, queue: .main) { notification in
            print("Notificación de ubicación actualizada recibida")
            if let userInfo = notification.userInfo,
               let xSitum = userInfo["xSitum"] as? Double,
               let ySitum = userInfo["ySitum"] as? Double,
               let yawSitum = userInfo["yawSitum"] as? Double,
               let floorIdentifier = userInfo["floorIdentifier"] as? Double{
                context.coordinator.updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum, floorIdentifier: floorIdentifier)
            } else {
                print("Datos inválidos recibidos en la notificación: \(String(describing: notification.userInfo))")
            }
        }
        
        // Suscribirse a la notificación para resetear las banderas
        NotificationCenter.default.addObserver(forName: .resetCoordinatorFlags, object: nil, queue: .main) { _ in
            context.coordinator.resetFlags()
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowAndTextPositionAndDirection()
        context.coordinator.updateTextOrientation()
        
        // Llamar a updatePOIs solo una vez cuando los datos estén disponibles
        if !context.coordinator.didUpdatePOIs && !poisMap.isEmpty && width > 0 {
            context.coordinator.updatePOIs(poisMap: poisMap, width: width)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

        // Crear y añadir la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }

        return anchor
    }

    class Coordinator: NSObject {
        var locationManager: LocationManager
        var arrowAndTextAnchor: AnchorEntity?
        var fixedAnchor: AnchorEntity?
        weak var arView: ARView?
        
        // Bandera para verificar si updatePOIs ha sido ejecutado
        var didUpdatePOIs = false

        // Nueva bandera para verificar si la ubicación ha sido actualizada
        var locationUpdated = false
        
        init(locationManager: LocationManager) {
            self.locationManager = locationManager
        }
        
        func setupFixedAnchor() {
            guard let arView = arView else { return }

            let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0)) // Posición fija en el espacio global
            fixedAnchor.name = "fixedPOIAnchor" // Asegúrate de que el nombre esté asignado

            // Crear y añadir el modelo animado
            do {
                let robotEntity = try ModelEntity.load(named: "Animated_Dragon_Three_Motion_Loops.usdz")
                robotEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
                robotEntity.position = SIMD3<Float>(-1.0, -10.0, -2.0) // Ajusta la posición según sea necesario
                
                // Rotar 45 grados (π/4 radianes) alrededor del eje Y
                let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
                robotEntity.orientation = rotation
                
                // Verificar y reproducir la animación "global scene animation"
                if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                    robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
                } else {
                    print("No se encontró la animación 'global scene animation'")
                }
                
                fixedAnchor.addChild(robotEntity)
            } catch {
                print("Error al cargar el modelo animado: \(error.localizedDescription)")
            }
            
            // Añadir el ancla de la esfera fija a la escena
            arView.scene.anchors.append(fixedAnchor)
            self.fixedAnchor = fixedAnchor
        }

        // Actualizar la ubicación solo una vez
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
            let newLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: ySitum, longitude: xSitum), altitude: floorIdentifier, horizontalAccuracy: kCLLocationAccuracyBest, verticalAccuracy: kCLLocationAccuracyBest, course: yawSitum, speed: 0, timestamp: Date())
            locationManager.initialLocation = newLocation

            // Marcar que la ubicación ha sido actualizada
            locationUpdated = true
        }
        
        func updateArrowAndTextPositionAndDirection() {
            guard let arView = arView, let arrowAndTextAnchor = arrowAndTextAnchor else { return }
            
            // Obtener la posición y rotación de la cámara
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            
            // Mantener la flecha y el texto a una distancia fija frente a la cámara
            let distance: Float = 2.0
            let forwardVector = -cameraTransform.matrix.columns.2.xyz
            let forwardPosition = cameraPosition + forwardVector * distance
            arrowAndTextAnchor.position = forwardPosition
            
            // **Ajustar la orientación para que la flecha apunte siempre al norte global**
            if let heading = locationManager.heading {
                let headingRadians = Float(heading.trueHeading + 90) * .pi / 180
                
                // Crear una orientación que apunte al norte global
                let northOrientation = simd_quatf(angle: headingRadians, axis: [0, -1, 0])
                
                // Establecer la orientación correcta para apuntar al norte global
                // El ángulo de la orientación se ajusta para que la flecha apunte correctamente
                if let arrowEntity = arrowAndTextAnchor.children.first {
                    arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * northOrientation
                }
            }
        }
        
        func updatePOIs(poisMap: [String: Any], width: Double) {
            // Verificar si la función ya ha sido ejecutada
            guard !didUpdatePOIs else { return }
            guard let arView = arView, let initialLocation = locationManager.initialLocation else { return }
            
            // Buscar el ancla fijo por nombre y convertirlo a AnchorEntity
            if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
                // Eliminar las entidades de POI existentes en el ancla fijo
                let existingPOIs = fixedPOIAnchor.children.filter {
                    let name = $0.name
                    return name.starts(with: "poi_") || name.starts(with: "text_")
                }
                
                // Eliminar las entidades encontradas
                existingPOIs.forEach { $0.removeFromParent() }

                // Agregar nuevos POIs
                guard let poisList = poisMap["pois"] as? [[String: Any]] else {
                    print("Error: No se encontró la clave 'pois' en el mapa de POIs")
                    return
                }
                print("WIDTH!!!!!!!!!!!!!!:       ", width)
                for (index, poi) in poisList.enumerated() {
                    if let position = poi["position"] as? [String: Any],
                       let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
                       let floorIdentifier = position["floorIdentifier"] as? String,
                       let x = cartesianCoordinate["x"],
                       let y = cartesianCoordinate["y"],
                       let name = poi["name"] as? String {
                        
                        if floorIdentifier == String(Int(initialLocation.altitude)) {
                            // Transformar la posición
                            let transformedPosition = generateARKitPosition(x: Float(x), y: Float(width - y), currentLocation: initialLocation, arView: arView)

                            // Crear la esfera y añadirla a la escena
                            let poiEntity = createSphereEntity(radius: 1, color: .green)
                            poiEntity.position = transformedPosition
                            poiEntity.name = "poi_\(index)"  // Asignar un nombre único a cada POI
                            print("POI:   ", name , "    ", poiEntity.position.x , "   ",poiEntity.position.z)
                            
                            // Crear la entidad de texto con el nombre del POI
                            let textEntity = createTextEntity(text: name, position: transformedPosition)
                            textEntity.name = "text_\(index)"  // Asignar un nombre único al texto
                            
                            // Añadir las entidades POI y el texto al ancla fijo
                            fixedPOIAnchor.addChild(poiEntity)
                            fixedPOIAnchor.addChild(textEntity)
                        }
                    } else {
                        print("Error: No se encontraron coordenadas cartesianas válidas para el POI \(index)")
                    }
                }

                // Asegurarse de que el ancla fijo está en la escena
                if !arView.scene.anchors.contains(where: { $0 as? AnchorEntity == fixedPOIAnchor }) {
                    arView.scene.anchors.append(fixedPOIAnchor)
                }
            } else {
                print("Error: No se encontró el ancla fijo con el nombre 'fixedPOIAnchor'")
            }
            
            didUpdatePOIs = true
        }

        // Restablecer las banderas de actualización
        func resetFlags() {
            didUpdatePOIs = false
            locationUpdated = false
            print("Flags reset: didUpdatePOIs and locationUpdated are now false!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!.")
        }

        func generateARKitPosition(x: Float, y: Float, currentLocation: CLLocation, arView: ARView) -> SIMD3<Float> {
            // Obtener la transformación de la cámara
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation  // SIMD3<Float>
            let cameraOrientation = cameraTransform.rotation  // simd_quatf

            // Calcular el vector hacia adelante de la cámara
            let forwardVector = cameraOrientation.act(SIMD3<Float>(0, 0, -1))
            let cameraBearing = atan2(forwardVector.x, forwardVector.z)  // Calcular el rumbo de la cámara

            // Ajustar la rotación para mantener solo la componente horizontal
            let cameraHorizontalRotation = simd_quatf(angle: cameraBearing, axis: SIMD3<Float>(0, 1, 0))

            // Rotación basada en la orientación del usuario
            let situmBearingDegrees = currentLocation.course
            guard situmBearingDegrees >= 0 else {
                return SIMD3<Float>(0, 0, 0)
            }
            let situmBearing = Float(situmBearingDegrees) + 90.0
            let situmBearingMinusRotation = simd_quatf(angle: situmBearing * .pi / 180.0, axis: SIMD3<Float>(0, -1, 0))

            // Calcular la posición relativa del POI respecto a la posición actual
            let relativePoiPosition = SIMD3<Float>(
                x - Float(currentLocation.coordinate.longitude),
                0,
                y - Float(currentLocation.coordinate.latitude)
            )

            // Rotar la posición relativa basándose en el rumbo del usuario
            let positionsMinusSitumRotated = situmBearingMinusRotation.act(relativePoiPosition)

            // Aplicar rotación horizontal de la cámara y trasladar a la posición de la cámara
            var positionRotatedAndTranslatedToCamera = cameraHorizontalRotation.act(positionsMinusSitumRotated)
            positionRotatedAndTranslatedToCamera += cameraPosition
            positionRotatedAndTranslatedToCamera.y = 0  // Mantener la altura constante

            // Retornar la posición transformada
            return positionRotatedAndTranslatedToCamera
        }
        
        func createSphereEntity(radius: Float, color: UIColor) -> ModelEntity {
            let sphereMesh = MeshResource.generateSphere(radius: radius)
            let material = SimpleMaterial(color: color, isMetallic: false)
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            return sphereEntity
        }

        func createTextEntity(text: String, position: SIMD3<Float>) -> ModelEntity {
            // Generar el texto
            let mesh = MeshResource.generateText(
                text,
                extrusionDepth: 0.02,  // Profundidad del texto para mayor visibilidad
                font: .systemFont(ofSize: 1.0),  // Aumentar el tamaño de la fuente
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            // Material visible (blanco o color que contraste con el fondo)
            let material = SimpleMaterial(color: .white, isMetallic: false)
            let textEntity = ModelEntity(mesh: mesh, materials: [material])
            
            // Aumentar el tamaño del texto
            textEntity.scale = SIMD3<Float>(0.5, 0.5, 0.5)  // Ajusta los valores para hacer el texto más grande
            textEntity.position = SIMD3<Float>(position.x, position.y + 0.5, position.z)
            
            return textEntity
        }
        
        func updateTextOrientation() {
            guard let arView = arView else { return }

            // Buscar el ancla fijo por nombre
            if let fixedPOIAnchor = arView.scene.anchors.first(where: { $0.name == "fixedPOIAnchor" }) as? AnchorEntity {
                
                // Iterar sobre los hijos del ancla fijo
                for child in fixedPOIAnchor.children {
                    if let textEntity = child as? ModelEntity, textEntity.name.starts(with: "text_") {
                        // Obtener la posición de la cámara
                        let cameraTransform = arView.cameraTransform
                        let cameraPosition = cameraTransform.translation
                        
                        // Orientar el texto para que mire a la cámara
                        textEntity.look(at: cameraPosition, from: textEntity.position, relativeTo: nil)
                        
                        // Aplicar una rotación de 180 grados en el eje Y para corregir la orientación
                        textEntity.orientation = simd_mul(
                            textEntity.orientation,
                            simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))  // Rotación 180 grados en Y
                        )
                    }
                }
            }
        }
    }
}

// Extensión para obtener el vector xyz de un simd_float4
extension simd_float4 {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}

// Extensión para aplicar rotaciones de cuaterniones a vectores
extension simd_quatf {
    func act(_ vector: SIMD3<Float>) -> SIMD3<Float> {
        let q = self
        let vq = simd_quatf(ix: vector.x, iy: vector.y, iz: vector.z, r: 0)
        let rotated = q * vq * q.inverse
        return SIMD3<Float>(rotated.imag.x, rotated.imag.y, rotated.imag.z)
    }
}
