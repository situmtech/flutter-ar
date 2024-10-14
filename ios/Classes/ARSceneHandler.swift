import Foundation
import ARKit
import RealityKit
import SitumSDK

/**
 ARSceneJuandler. Manage AR world.
 */
@available(iOS 13.0, *)
class ARSceneHandler: NSObject, ARSessionDelegate, SITLocationDelegate, SITNavigationDelegate {
    
    /**
     Called once after initialization.
     */
    func setupSceneView(arSceneView: CustomARSceneView) {

        let arView = ARView(frame: .zero)
        arView.cameraMode = .ar
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arView.session.run(configuration)
        
       /* context.coordinator.arView = arView
        context.coordinator.setupFixedAnchor()
        
        // Establecer el delegado de la sesión para recibir actualizaciones
        arView.session.delegate = context.coordinator

       // context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        
        // Agregar la luz direccional
        addDirectionalLight(to: arView)
        
        
        //Arrow
        let arrowAnchor = createArrowAnchor()
        arView.scene.anchors.append(arrowAnchor)
        context.coordinator.arrowAnchor = arrowAnchor
        */
        //Dinamyc model
        let fixedAnchorModel = setupDynamicModel()
        arView.scene.anchors.append(fixedAnchorModel)
        
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
        
            let tRexEntity = try ModelEntity.load(named: "T-Rex.usdz")
            tRexEntity.scale = SIMD3<Float>(0.015, 0.015, 0.015)
            tRexEntity.position = SIMD3<Float>(-2.0, -1.5, -20.0)
            
            if let animation = tRexEntity.availableAnimations.first(where: { $0.name == "global scene animation" }) {
                tRexEntity.playAnimation(animation.repeat(), transitionDuration: 0.5, startsPaused: false)
            }
            
            fixedAnchorModel.addChild(robotEntity)
            fixedAnchorModel.addChild(tRexEntity)
            
        } catch {
            print("Error al cargar el modelo animado: \(error.localizedDescription)")
        }
        
        return fixedAnchorModel
    }
    /**
     Called once per frame.
     */
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
    }
    
    // MARK: Communication Manager callbacks:
    
    func onBuildingInfoReceived(_ buildingInfo: SITBuildingInfo?, withError error: Error?) {
        print("Situm> Building info received: \(String(describing: buildingInfo))")
        print("Situm> Got \(buildingInfo?.indoorPois.count ?? 0) POIs: \(String(describing: buildingInfo?.indoorPois))")
    }
    
    // MARK: LocationManager delegate.
    
    func locationManager(_ locationManager: any SITLocationInterface, didUpdate location: SITLocation) {
        print("Situm> Location received: \(location)")
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didFailWithError error: (any Error)?) {
        print("Situm> Location encountered an error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didUpdate state: SITLocationState) {
        print("Situm> Location state changed: \(state)")
    }
    
    // MARK: NavigationManager delegate.
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didStartOn route: SITRoute) {
        print("Situm> Navigation started on route: \(route)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didFailWithError error: Error) {
        print("Situm> Navigation encountered an error: \(error.localizedDescription)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didUpdate progress: SITNavigationProgress, on route: SITRoute) {
        print("Situm> Progress updated on route: \(route), progress: \(progress)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, destinationReachedOn route: SITRoute) {
        print("Situm> Destination reached on route: \(route)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, userOutsideRoute route: SITRoute) {
        print("Situm> User is outside the route: \(route)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didCancelOn route: SITRoute) {
        print("Situm> Navigation cancelled on route: \(route)")
    }
}
