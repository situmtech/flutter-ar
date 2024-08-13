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
        
        // Crear y añadir el ancla para la flecha
        let arrowAnchor = createArrowAnchor()
        arView.scene.anchors.append(arrowAnchor)
        
        context.coordinator.arrowAnchor = arrowAnchor
        context.coordinator.arView = arView
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowPositionAndDirection()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }
    
    func createArrowAnchor() -> AnchorEntity {
        let anchor = AnchorEntity(world: [0, 0, 0])
        
        do {
            // Intenta cargar el modelo
            let modelEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            modelEntity.scale = SIMD3<Float>(0.05, 0.05, 0.05)
            anchor.addChild(modelEntity)
            print("Modelo cargado exitosamente.")
        } catch {
            // Si hay un error al cargar el modelo, lo loguea
            print("Error al cargar el modelo: \(error.localizedDescription)")
        }
        
        return anchor
    }
    
    class Coordinator: NSObject, CLLocationManagerDelegate {
        var locationManager: LocationManager
        var arrowAnchor: AnchorEntity?
        weak var arView: ARView?

        init(locationManager: LocationManager) {
            self.locationManager = locationManager
            super.init()
            locationManager.manager.delegate = self
            locationManager.manager.startUpdatingHeading()
        }
        
        func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
            updateArrowPositionAndDirection()
        }
        
        func updateArrowPositionAndDirection() {
            guard let arView = arView, let arrowAnchor = arrowAnchor, let modelEntity = arrowAnchor.children.first else { return }

            let cameraTransform = arView.cameraTransform.matrix
            let cameraPosition = cameraTransform.translation

            let distance: Float = 2.5
            let forwardPosition = cameraPosition + cameraTransform.forwardVector * distance
            if distanceBetween(arrowAnchor.position, forwardPosition) > 0.05 {
                arrowAnchor.position = forwardPosition
            }

            let northRotation = locationManager.getRotationToMagneticNorth()
            let northQuaternion = simd_quatf(angle: northRotation, axis: [1, 0, 0])
            let cameraRotation = arView.cameraTransform.rotation
            modelEntity.orientation = cameraRotation * northQuaternion
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
