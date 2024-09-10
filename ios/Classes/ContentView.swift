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
        let anchor = AnchorEntity() // Usar un ancla sin posición inicial fija
        
        // Crear y añadir la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.1, 0.1, 0.1)
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }
        
        // Crear y añadir el texto
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
        
        return textEntity
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
            
            // Actualizar la orientación de la flecha para que apunte al norte
            if let heading = locationManager.heading {
                let headingRadians = Float(heading.trueHeading) * .pi / 180
                let northOrientation = simd_quatf(angle: headingRadians, axis: [0, 1, 0])
                arrowAndTextAnchor.orientation = northOrientation
            }
        }
        
        func updatePOIs(poisMap: [String: Any]) {
            // Implementar la lógica para actualizar POIs en la vista AR
            // Puedes añadir o actualizar los POIs en función de `poisMap`
            // Ejemplo básico: solo imprimir los POIs para depuración
            NSLog("Updating POIs in AR with data: \(poisMap)")
            
            // Aquí puedes agregar o actualizar POIs en la escena AR si es necesario
        }
    }
}

// Extensión para obtener el vector xyz de un float4x4
extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
