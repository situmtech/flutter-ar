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
        arView.cameraMode = .ar
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arView.session.run(configuration)
        
        let yawLabel = UILabel()
        yawLabel.frame = CGRect(x: 20, y: 20, width: 200, height: 50)
        yawLabel.textColor = .white
        yawLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        yawLabel.textAlignment = .center
        yawLabel.text = "Yaw: 0.0°"
        // Añadir la etiqueta al ARView
        arView.addSubview(yawLabel)
        // Guardar referencias para actualizar el yaw
        context.coordinator.arView = arView
        context.coordinator.yawLabel = yawLabel
        context.coordinator.setupFixedAnchor()
        // Establecer el delegado de la sesión para recibir actualizaciones
        arView.session.delegate = context.coordinator

       // context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        //Arrow
        let arrowAnchor = createArrowAnchor()
        arView.scene.anchors.append(arrowAnchor)
        context.coordinator.arrowAnchor = arrowAnchor
        
        //Dinamyc model
        let fixedAnchorModel = setupDynamicModel()
        arView.scene.anchors.append(fixedAnchorModel)
        //context.coordinator.arrowAnchor = arrowAnchor
       

        NotificationCenter.default.addObserver(forName: .locationUpdated, object: nil, queue: .main) { notification in
            context.coordinator.handleLocationUpdate(notification)
        }
        
        NotificationCenter.default.addObserver(forName: .updatePointsList, object: nil, queue: .main) { notification in
            context.coordinator.handlePointUpdate(notification)
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

    func createArrowAnchor() -> AnchorEntity {
        let anchor = AnchorEntity()

        do {
            let arrowEntity = try ModelEntity.load(named: "arrow_situm.usdz")
            arrowEntity.scale = SIMD3<Float>(0.025, 0.025, 0.025)
            arrowEntity.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
            arrowEntity.position = SIMD3<Float>(0.0, -0.5, -0.5)
            anchor.addChild(arrowEntity)
        } catch {
            print("Error al cargar el modelo de la flecha: \(error.localizedDescription)")
        }

        return anchor
    }
    
    func setupDynamicModel() -> AnchorEntity{
        let fixedAnchorModel = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        do {
            let robotEntity = try ModelEntity.load(named: "Animated_Dragon_Three_Motion_Loops.usdz")
            robotEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
            robotEntity.position = SIMD3<Float>(1.0, -0.25, -3.0)

            let rotation = simd_quatf(angle: .pi / 4, axis: SIMD3<Float>(0, 1, 0))
            robotEntity.orientation = rotation

            if let animation = robotEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                robotEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }
            fixedAnchorModel.addChild(robotEntity)
        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }
        
        return fixedAnchorModel
    }
    
    
}
