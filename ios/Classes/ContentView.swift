import SwiftUI
import RealityKit
import ARKit
import CoreLocation

@available(iOS 13.0, *)
struct ContentView: View {
    var body: some View {
        ARViewContainer().edgesIgnoringSafeArea(.all)
    }
}

@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @ObservedObject private var locationManager = LocationManager()

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
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowAndTextPositionAndDirection()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity(world: [0, -1, 0])
        
        // Cargar el modelo de la flecha
        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
            let rotationAngle: Float = .pi / 2 // 90 grados en radianes
            arrowEntity.orientation = simd_quatf(angle: rotationAngle, axis: [0, 1, 0])
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo: \(error.localizedDescription)")
        }
        
        // Crear y configurar el texto
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
        textEntity.position = [-1.0, -4.0, 0.0] // Ajusta la posición según sea necesario
        textEntity.scale = SIMD3<Float>(5.0, 5.0, 5.0)
        
        // Rotar el texto para que esté en horizontal y no esté volteado
        let textRotationAngle: Float = -.pi / 2 // Rotar 90 grados en sentido contrario en el eje Z
        let flipRotationAngle: Float = .pi // Rotar 180 grados en el eje Y para corregir el volteo
        
        // Segunda rotación que quieres aplicar
        let secondRotationAngle: Float = .pi / 2 // 90 grados en radianes
        let secondRotationAxis = SIMD3<Float>(0, 1, 0) // Eje Y para rotación alrededor del eje Y
        
        // Crear quaterniones para cada rotación
        let textRotationQuaternion = simd_quatf(angle: textRotationAngle, axis: [0, 0, 1])
        let flipRotationQuaternion = simd_quatf(angle: flipRotationAngle, axis: [0, 0, 1])
        let secondRotationQuaternion = simd_quatf(angle: secondRotationAngle, axis: secondRotationAxis)
        
        // Combinar las rotaciones
        let combinedQuaternion = textRotationQuaternion * flipRotationQuaternion * secondRotationQuaternion
        
        // Aplicar la rotación combinada al texto
        textEntity.orientation = combinedQuaternion
        
        anchor.addChild(textEntity)
        
        return anchor
    }

    
    class Coordinator: NSObject, CLLocationManagerDelegate {
        var locationManager: LocationManager
        var arrowAndTextAnchor: AnchorEntity?
        weak var arView: ARView?

        init(locationManager: LocationManager) {
            self.locationManager = locationManager
            super.init()
            locationManager.manager.delegate = self
            locationManager.manager.startUpdatingHeading()
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            updateArrowAndTextPositionAndDirection()
        }
        
        func updateArrowAndTextPositionAndDirection() {
            guard let arView = arView, let arrowAndTextAnchor = arrowAndTextAnchor else { return }

            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = cameraTransform.translation

            let distance: Float = 2.5
            let forwardPosition = cameraPosition + cameraTransform.forwardVector * distance
            if distanceBetween(arrowAndTextAnchor.position, forwardPosition) > 0.05 {
                arrowAndTextAnchor.position = forwardPosition
            }

            let northRotation = locationManager.getRotationToMagneticNorth()
            let northQuaternion = simd_quatf(angle: northRotation, axis: [1, 0, 0])
            let cameraRotation = arView.cameraTransform.rotation
            arrowAndTextAnchor.orientation = cameraRotation * northQuaternion
        }
        
        func distanceBetween(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
            return simd_distance(a, b)
        }
    }
}

@available(iOS 13.0, *)
class LocationManager: NSObject, ObservableObject {
    var manager = CLLocationManager()

    override init() {
        super.init()
        manager.headingFilter = kCLHeadingFilterNone
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.startUpdatingHeading()
    }

    func getRotationToMagneticNorth() -> Float {
        guard let heading = manager.heading else {
            return 0.0
        }
        return -Float(heading.magneticHeading) * .pi / 180 + (.pi/2.0)
    }
}

@available(iOS 13.0, *)
extension ARView {
    var cameraTransform: Transform {
        return Transform(matrix: self.session.currentFrame?.camera.transform ?? matrix_identity_float4x4)
    }
}

@available(iOS 13.0, *)
extension float4x4 {
    var translation: SIMD3<Float> {
        return SIMD3<Float>(self.columns.3.x, self.columns.3.y, self.columns.3.z)
    }
    
    var forwardVector: SIMD3<Float> {
        return SIMD3<Float>(-self.columns.2.x, -self.columns.2.y, -self.columns.2.z)
    }
}

@available(iOS 13.0, *)
extension Transform {
    var rotation: simd_quatf {
        return simd_quatf(self.rotationMatrix)
    }
    
    var rotationMatrix: float3x3 {
        return float3x3([self.matrix.columns.0.x, self.matrix.columns.0.y, self.matrix.columns.0.z],
                        [self.matrix.columns.1.x, self.matrix.columns.1.y, self.matrix.columns.1.z],
                        [self.matrix.columns.2.x, self.matrix.columns.2.y, self.matrix.columns.2.z])
    }
}
