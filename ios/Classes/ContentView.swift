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
            
            // Asegúrate de que la flecha apunta hacia el eje Z positivo en el modelo
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
                let northOrientation = simd_quatf(angle: headingRadians, axis: [0, 1, 0])
                
                // Establecer la orientación correcta para apuntar al norte global
                // El ángulo de la orientación se ajusta para que la flecha apunte correctamente
                let arrowEntity = arrowAndTextAnchor.children.first!
                arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0]) * northOrientation
            }
        }
        
        func updatePOIs(poisMap: [String: Any]) {
            // Implementar la lógica para actualizar POIs en la vista AR
            NSLog("Updating POIs in AR with data: \(poisMap)")
        }
    }
}

// Extensión para obtener el vector xyz de un float4x4
extension SIMD4<Float> {
    var xyz: SIMD3<Float> {
        return SIMD3<Float>(x, y, z)
    }
}
