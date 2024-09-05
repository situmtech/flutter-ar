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
        ARViewContainer(poisMap: poisMap)
            .edgesIgnoringSafeArea(.all)
            .onReceive(NotificationCenter.default.publisher(for: .poisUpdated)) { _ in
                // Manejar actualización de POIs si es necesario
            }
    }
}

// Vista ARViewContainer
@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject private var locationManager = LocationManager()
    var poisMap: [String: Any]

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // Configuración de ARKit
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        arView.session.run(configuration)
        
        // Crear y añadir el ancla para la flecha y el texto
        let arrowAndTextAnchor = createArrowAndTextAnchor()
        arView.scene.anchors.append(arrowAndTextAnchor)
        
        context.coordinator.arrowAndTextAnchor = arrowAndTextAnchor
        context.coordinator.arView = arView
        context.coordinator.poisMap = poisMap

        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowAndTextPositionAndDirection()
        // Actualizar POIs si es necesario
        if !poisMap.isEmpty {
            context.coordinator.updatePOIs(poisMap: poisMap)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity(world: SIMD3(x: 0, y: -1, z: -2)) // Ajusta la posición inicial si es necesario
        
        // Crear y añadir la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.1, 0.1, 0.1)
            // La flecha debe apuntar hacia adelante en el plano horizontal
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }
        
        // Crear y añadir el texto usando una función separada
        let textEntity = createTextEntity()
        anchor.addChild(textEntity)
        
        return anchor
    }

    func createTextEntity() -> ModelEntity {
        let textMesh = MeshResource.generateText(
            "Sigue la flecha!",
            extrusionDepth: 0.01,
            font: .systemFont(ofSize: 0.1),
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )
        let material = SimpleMaterial(color: .white, isMetallic: false)
        let textEntity = ModelEntity(mesh: textMesh, materials: [material])
        
        // Posicionar el texto debajo de la flecha
        textEntity.position = [0.0, -0.5, 0.0] // Ajusta la posición según sea necesario
        textEntity.scale = SIMD3<Float>(2.0, 2.0, 2.0)
        
        // Rotar el texto para que esté en horizontal y no esté volteado
        let textRotationAngle: Float = .pi / 2 // Rotar 90 grados en el eje Z
        let textRotationQuaternion = simd_quatf(angle: textRotationAngle, axis: [0, 0, 1])
        textEntity.orientation = textRotationQuaternion
        
        return textEntity
    }

    class Coordinator: NSObject, CLLocationManagerDelegate {
        var locationManager: LocationManager
        var arrowAndTextAnchor: AnchorEntity?
        weak var arView: ARView?
        var poisMap: [String: Any] = [:]

        init(locationManager: LocationManager) {
            self.locationManager = locationManager
            super.init()
            // El coordinator usa la instancia de LocationManager que ya tiene el delegate configurado
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            updateArrowAndTextPositionAndDirection()
        }
        
        func updateArrowAndTextPositionAndDirection() {
            guard let arView = arView, let arrowAndTextAnchor = arrowAndTextAnchor else { return }
            
            // Obtener la posición y rotación de la cámara
            let cameraTransform = arView.cameraTransform
            let cameraPosition = cameraTransform.translation
            let cameraRotation = cameraTransform.rotation
            
            // Ajustar la posición de la flecha frente a la cámara
            let distance: Float = 2.5
            let forwardVector = -cameraTransform.matrix.columns.2.xyz
            let forwardPosition = cameraPosition + forwardVector * distance
            arrowAndTextAnchor.position = forwardPosition
            
            // Actualizar la rotación de la flecha para que apunte hacia la cámara
            let targetDirection = forwardVector
            let currentDirection = SIMD3<Float>(0, 0, 1) // Asumiendo que la flecha está orientada hacia adelante en el espacio local
            let angle = acos(dot(currentDirection, targetDirection) / (length(currentDirection) * length(targetDirection)))
            let axis = cross(currentDirection, targetDirection)
            arrowAndTextAnchor.orientation = simd_quatf(angle: angle, axis: axis)
        }
        
        func updatePOIs(poisMap: [String: Any]) {
            // Implementar lógica para colocar POIs en la vista AR
            // Crear objetos AR para cada POI y añadirlos a la escena
        }
    }
}

// Extensión para obtener el vector xyz de un float4x4
extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
