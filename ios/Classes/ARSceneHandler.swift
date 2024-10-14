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
    var arView: ARView?  // Definir arView como propiedad de la clase
    var fixedAnchor: AnchorEntity?
    
    func setupSceneView(arSceneView: CustomARSceneView) {

        //let arView = ARView(frame: arSceneView.bounds)
        arSceneView.cameraMode = .ar
        arSceneView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arSceneView.session.run(configuration)
        
        //Fija un ancla en el origen de coordenadas
        setupFixedAnchor(arSceneView: arSceneView)

       /* context.coordinator.arView = arView
        context.coordinator.setupFixedAnchor()
        
        // Establecer el delegado de la sesión para recibir actualizaciones
        arView.session.delegate = context.coordinator

       // context.coordinator.arView = arView
        arView.session.delegate = context.coordinator
        */
        
        // Agregar la luz direccional
        addDirectionalLight(to: arSceneView)
        
        
        //Arrow
        let arrowAnchor = createArrowAnchor()
        arSceneView.scene.anchors.append(arrowAnchor)
        /*context.coordinator.arrowAnchor = arrowAnchor*/
        
        //Setup animated model
        let fixedAnchorModel = setupDynamicModel()
        arSceneView.scene.anchors.append(fixedAnchorModel)
    
        
    }
    
    func setupFixedAnchor(arSceneView: CustomARSceneView) {
        //guard let arView = arSceneView else { return }

        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        arSceneView.scene.anchors.append(fixedAnchor)
        self.fixedAnchor = fixedAnchor
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
