import SwiftUI
import RealityKit
import ARKit

@available(iOS 13.0, *)
struct ARViewContainer: UIViewRepresentable {
    @Binding var poisMap: [String: Any]
    @ObservedObject var locationManager: LocationManager
    var width: Double

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        arView.session.run(configuration)

        let arrowAndTextAnchor = createArrowAndTextAnchor()
        arView.scene.anchors.append(arrowAndTextAnchor)

        context.coordinator.arView = arView
        arView.session.delegate = context.coordinator

        context.coordinator.arrowAndTextAnchor = arrowAndTextAnchor
        context.coordinator.setupFixedAnchor()

        NotificationCenter.default.addObserver(forName: .locationUpdated, object: nil, queue: .main) { notification in
            context.coordinator.handleLocationUpdate(notification)
        }

        NotificationCenter.default.addObserver(forName: .resetCoordinatorFlags, object: nil, queue: .main) { _ in
            context.coordinator.resetFlags()
        }

        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.updateArrowPositionAndDirection()
        context.coordinator.updateTextOrientation()

        if !context.coordinator.didUpdatePOIs && !poisMap.isEmpty && width > 0 {
            context.coordinator.updatePOIs(poisMap: poisMap, width: width)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(locationManager: locationManager)
    }

    func createArrowAndTextAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

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
}
