import SwiftUI
import RealityKit
import ARKit
import CoreLocation

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

    init(poisMap: [String: Any]) {
        _poisMap = State(initialValue: poisMap)
    }

    var body: some View {
        ARViewContainer(poisMap: $poisMap, locationManager: locationManager)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: .poisUpdated)) { notification in
                if let poisMap = notification.userInfo?["poisMap"] as? [String: Any] {
                    self.poisMap = poisMap
                } else {
                    print("Failed to cast POIs map. UserInfo: \(String(describing: notification.userInfo))")
                }
            }
    }
}

// Vista ARViewContainer
@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @Binding var poisMap: [String: Any]
    @ObservedObject var locationManager: LocationManager

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
               let yawSitum = userInfo["yawSitum"] as? Double {
                print("Datos recibidos: xSitum = \(xSitum), ySitum = \(ySitum), yawSitum = \(yawSitum)")

                // Manejar la actualización de ubicación aquí
                context.coordinator.updateLocation(xSitum: xSitum, ySitum: ySitum, yawSitum: yawSitum)
            }else {
                print("Datos inválidos recibidos en la notificación: \(String(describing: notification.userInfo))")
            }
        }
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowAndTextPositionAndDirection()
        context.coordinator.updatePOIs(poisMap: poisMap)
        context.coordinator.updateTextOrientation()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

        // Crear y añadir la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.051, 0.051, 0.051)
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            arrowEntity.position = SIMD3<Float>(0.0, 0.0, 0.0)
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }

        // Crear y añadir el texto
        let textEntity = createTextEntity()
        anchor.addChild(textEntity)

        // Añadir los ejes XYZ y sus etiquetas
        let axisEntities = createAxisEntities()
        anchor.addChild(axisEntities.xAxis)
        anchor.addChild(axisEntities.yAxis)
        anchor.addChild(axisEntities.zAxis)

        let xAxisLabel = createLabelEntity(text: "X", position: [1.1, 0, 0], color: .red)
        let yAxisLabel = createLabelEntity(text: "Y", position: [0, 1.1, 0], color: .green)
        let zAxisLabel = createLabelEntity(text: "Z", position: [0, 0, 1.1], color: .blue)

        anchor.addChild(xAxisLabel)
        anchor.addChild(yAxisLabel)
        anchor.addChild(zAxisLabel)

        return anchor
    }



    func createTextEntity() -> ModelEntity {
        let textMesh = MeshResource.generateText(
            " Flecha!",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        
        // Posicionar el texto debajo de la flecha
        textEntity.position = [0.0, -0.5, 0.0]
        textEntity.scale = SIMD3<Float>(2.0, 2.0, 2.0)
        
        return textEntity
    }

    func createAxisEntities() -> (xAxis: ModelEntity, yAxis: ModelEntity, zAxis: ModelEntity) {
        let axisLength: Float = 1.0
        
        let xAxis = createLineEntity(start: [0, 0, 0], end: [axisLength, 0, 0], color: .red)
        let yAxis = createLineEntity(start: [0, 0, 0], end: [0, axisLength, 0], color: .green)
        let zAxis = createLineEntity(start: [0, 0, 0], end: [0, 0, axisLength], color: .blue)
        
        return (xAxis, yAxis, zAxis)
    }

    func createLineEntity(start: SIMD3<Float>, end: SIMD3<Float>, color: UIColor) -> ModelEntity {
        let lineMesh = MeshResource.generateBox(size: [0.01, lengthBetween(start, end), 0.01])
        let material = SimpleMaterial(color: color, isMetallic: false)
        let lineEntity = ModelEntity(mesh: lineMesh, materials: [material])
        
        let midPoint = (start + end) / 2
        let direction = normalize(end - start)
        lineEntity.position = midPoint
        lineEntity.orientation = simd_quatf(from: SIMD3<Float>(0, 1, 0), to: direction)
        
        return lineEntity
    }

    func lengthBetween(_ start: SIMD3<Float>, _ end: SIMD3<Float>) -> Float {
        return length(end - start)
    }

    func createLabelEntity(text: String, position: SIMD3<Float>, color: UIColor) -> ModelEntity {
        let textMesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: color, isMetallic: false)
        let labelEntity = ModelEntity(mesh: textMesh, materials: [material])
        
        labelEntity.position = position
        labelEntity.scale = SIMD3<Float>(1.0, 1.0, 1.0)
        
        return labelEntity
    }

    class Coordinator: NSObject {
        var locationManager: LocationManager
        var arrowAndTextAnchor: AnchorEntity?
        var fixedAnchor: AnchorEntity?
        weak var arView: ARView?
        
        init(locationManager: LocationManager) {
            self.locationManager = locationManager
        }
        
        func setupFixedAnchor() {
            guard let arView = arView else { return }

            let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0)) // Posición fija en el espacio global
            fixedAnchor.name = "fixedPOIAnchor" // Asegúrate de que el nombre esté asignado

            // Crear y añadir el modelo animado de "Manta.usdz"
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

        func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double) {
            guard let arView = arView else { return }

            // Actualizar la posición en la vista AR usando la nueva ubicación
            // Aquí podrías actualizar la posición de un marcador en la vista AR, por ejemplo
            
            //print("X_SITUM:  ", xSitum)
            //print("Y_SITUM:  ", ySitum)
            //print("YAW_SITUM:  ", yawSitum)
            let locationPosition = SIMD3<Float>(Float(xSitum), Float(ySitum), Float(yawSitum))
            
            let newLocation = CLLocation(coordinate: CLLocationCoordinate2D(latitude: ySitum, longitude: xSitum), altitude: 0, horizontalAccuracy: kCLLocationAccuracyBest, verticalAccuracy: kCLLocationAccuracyBest, course: yawSitum, speed: 0, timestamp: Date())
            
            locationManager.initialLocation = newLocation
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
                let arrowEntity = arrowAndTextAnchor.children.first!
                arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * northOrientation
            }
        }
        
        func updatePOIs(poisMap: [String: Any]) {
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
                
                for (index, poi) in poisList.enumerated() {
                    if let position = poi["position"] as? [String: Any],
                       let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
                       let x = cartesianCoordinate["x"],
                       let y = cartesianCoordinate["y"],
                       let name = poi["name"] as? String {

                        let transformedPosition = transformPosition(x: Float(x), y: Float(y), referenceLocation: initialLocation)

                        // Crear la esfera y añadirla a la escena
                        let poiEntity = createSphereEntity(radius: 1, color: .green)
                        poiEntity.position = transformedPosition
                        poiEntity.name = "poi_\(index)"  // Asignar un nombre único a cada POI

                        // Crear la entidad de texto con el nombre del POI
                        let textEntity = createTextEntity(text: name, position: transformedPosition)
                        textEntity.name = "text_\(index)"  // Asignar un nombre único al texto

                        // Añadir las entidades POI y el texto al ancla fijo
                        fixedPOIAnchor.addChild(poiEntity)
                        fixedPOIAnchor.addChild(textEntity)
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
        }



        // Transformar la posición de los POIs al sistema de referencia de la cámara
        func transformPosition(x: Float, y: Float, referenceLocation: CLLocation) -> SIMD3<Float> {
            // Aplicar traslación restando la posición de referencia
            let xTranslated = x - Float(referenceLocation.coordinate.longitude)
            let yTranslated = y - Float(referenceLocation.coordinate.latitude)
            
            // Convertir el ángulo de rotación
            let rotationAngle = Float(referenceLocation.course + 90.0) * .pi / 180.0
            let rotationMatrix = float4x4(simd_quatf(angle: rotationAngle, axis: [0, 0, 1]))
            
            // Aplicar rotación
            let translation = SIMD3<Float>(xTranslated, yTranslated, 0.0)
            let transformedPosition = rotationMatrix * SIMD4<Float>(translation.x, translation.y, 0, 1)
            
            return SIMD3<Float>(transformedPosition.x, -1, transformedPosition.y)
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
                extrusionDepth: 0.02,  // Profundidad mayor para mayor visibilidad
                font: .systemFont(ofSize: 0.3),  // Tamaño de la fuente aumentado
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byWordWrapping
            )
            
            // Material visible (blanco o color que contraste con el fondo)
            let material = SimpleMaterial(color: .white, isMetallic: false)
            
            let textEntity = ModelEntity(mesh: mesh, materials: [material])
            
            // Ajustar la escala del texto para hacerlo más visible
            textEntity.scale = SIMD3<Float>(1, 1, 1)  // Ajusta la escala según tu escena
            
            // Ajustar la posición del texto, ligeramente por encima de la esfera
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
                        
                        // Orientar el texto para que siempre esté mirando a la cámara
                        textEntity.look(at: cameraPosition, from: textEntity.position, relativeTo: nil)
                    }
                }
            }
        }






    }
}

// Extensión para obtener el vector xyz de un float4x4
extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
