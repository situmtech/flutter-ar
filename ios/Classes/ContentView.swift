import SwiftUI
import RealityKit
import ARKit
import CoreLocation

// Clase LocationManager para manejar la ubicación
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published var heading: CLHeading?
    
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
        
        // Crear y añadir el ancla para la flecha y el texto
        let arrowAndTextAnchor = createArrowAndTextAnchor()
        arView.scene.anchors.append(arrowAndTextAnchor)
        
        context.coordinator.arrowAndTextAnchor = arrowAndTextAnchor
        context.coordinator.arView = arView

        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowAndTextPositionAndDirection()
        context.coordinator.updatePOIs(poisMap: poisMap)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

        // Crear y añadir la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.1, 0.1, 0.1)
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
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

        // Crear y añadir el modelo animado de "robot.usdz"
        do {
            let robotEntity = try ModelEntity.load(named: "Manta_Ray_Birostris_animated.usdz")
            robotEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
            robotEntity.position = SIMD3<Float>(0.0, 0.0, -30.0) // Ajusta la posición según sea necesario
            
            // Rotar 45 grados (π/4 radianes) alrededor del eje Y
            let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            robotEntity.orientation = rotation
            
            // Verificar y reproducir la animación "global scene animation"
            if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            } else {
                print("No se encontró la animación 'global scene animation'")
            }
            
            anchor.addChild(robotEntity)
        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }




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
        weak var arView: ARView?
        
        init(locationManager: LocationManager) {
            self.locationManager = locationManager
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
                let headingRadians = Float(heading.trueHeading) * .pi / 180
                
                // Crear una orientación que apunte al norte global
                let northOrientation = simd_quatf(angle: headingRadians, axis: [0, -1, 0])
                
                // Establecer la orientación correcta para apuntar al norte global
                // El ángulo de la orientación se ajusta para que la flecha apunte correctamente
                let arrowEntity = arrowAndTextAnchor.children.first!
                arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * northOrientation
            }
        }
        
        func updatePOIs(poisMap: [String: Any]) {
            guard let arView = arView else { return }

            // Extraer la lista de POIs desde el diccionario "pois"
            guard let poisList = poisMap["pois"] as? [[String: Any]] else {
                print("Error: No se encontró la clave 'pois' en el mapa de POIs")
                return
            }

            // Imprimir el número de POIs recibidos
            print("Número de POIs: \(poisList.count)")

            // Eliminar las anclas anteriores
            let anchorsToRemove = arView.scene.anchors.filter { anchor in
                return anchor.name.starts(with: "poi_")
            }
            for anchor in anchorsToRemove {
                arView.scene.anchors.remove(anchor)
            }

            // Procesar cada POI
            for (index, poi) in poisList.enumerated() {
                if let position = poi["position"] as? [String: Any],
                   let cartesianCoordinate = position["cartesianCoordinate"] as? [String: Double],
                   let x = cartesianCoordinate["x"],
                   let y = cartesianCoordinate["y"] {

                    // Ajustar la posición Z según tu necesidad, aquí pongo 0 como ejemplo
                    let z: Float = 0.0

                    let poiPosition = SIMD3<Float>(Float(x), Float(y), z)

                    // Imprimir las coordenadas del POI
                    print("POI \(index): (x: \(x), y: \(y), z: \(z))")

                    // Crear la esfera y añadirla a la escena
                    let poiEntity = createSphereEntity(radius: 1, color: .blue)
                    poiEntity.position = poiPosition
                    let poiAnchor = AnchorEntity(world: poiPosition)
                    poiAnchor.name = "poi_\(index)"
                    poiAnchor.addChild(poiEntity)
                    arView.scene.anchors.append(poiAnchor)
                } else {
                    print("Error: No se encontraron coordenadas cartesianas válidas para el POI \(index)")
                }
            }
        }


        
        func createSphereEntity(radius: Float, color: UIColor) -> ModelEntity {
            let sphereMesh = MeshResource.generateSphere(radius: radius)
            let material = SimpleMaterial(color: color, isMetallic: false)
            let sphereEntity = ModelEntity(mesh: sphereMesh, materials: [material])
            return sphereEntity
        }

    }
}

// Extensión para obtener el vector xyz de un float4x4
extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
