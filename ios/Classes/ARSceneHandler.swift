import Foundation
import ARKit
import RealityKit
import SitumSDK

/**
 ARSceneJuandler. Manage AR world.
 */

protocol ARSceneHandlerDelegate: AnyObject {
    func didReachDestination()
}


@available(iOS 15.0, *)
class ARSceneHandler: NSObject, ARSessionDelegate, SITLocationDelegate, SITNavigationDelegate, SITGeofencesDelegate {

    weak var delegate: ARSceneHandlerDelegate?
    
    var coordinator: Coordinator?

    var arQuality: ARQuality?
    var configDebug: ConfigDebug?
    var refreshingTimer = 5
    var timestampLastRefresh = 0
    var hasToRefresh = true
       
    var mainAnchor: AnchorEntity?
    var updateTimer: Timer?
    var cameraDeph = 25.0
    
    var sitArData: SITArData?
    var lastTimestamp = 0
    var sitExternalSensorManager: SITExternalSensorManager?
    
    var locationsBuffer: [String?] = Array(repeating: nil, count: 10)
    var currentIndex = 0 // Índice para controlar la posición de inserción
    var hasToResetChangeFloor = false
    
    var staticRoute: [[String: Any]] = []
    private var currentGeofences: [SITGeofence] = []
    var destinationPoiName:String? = nil
    
    
    func setupSceneView(arSceneView: CustomARSceneView) {

        arSceneView.cameraMode = .ar
        arSceneView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arSceneView.session.run(configuration)
             
        arQuality = ARQuality()
        sitArData = SITArData()
        sitExternalSensorManager = SITExternalSensorManager()
        setupFixedAnchor(arSceneView: arSceneView)

        //Lights
        setupLighting(arView: arSceneView)
        
        //Debug panel
        configDebug = ConfigDebug(arQuality: arQuality, hasToRefresh: hasToRefresh)
        
        // Initializes the timer to adjust the visibility of objects based on distance
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let mainAnchor = self.mainAnchor else { return }
            self.adjustVisibilityBasedOnDistance(arSceneView: arSceneView, mainAnchor: mainAnchor, nearDistance: 2.0, farDistance: Float(cameraDeph))
        }
            
       
        // Instance of the Coordinator
        self.coordinator = makeCoordinator()
        self.coordinator?.arView = arSceneView
        
        //Arrow
        self.coordinator?.initArrowToRoute(staticRoute) 
        let arrowAnchor = createArrowAnchor()
        arSceneView.scene.anchors.append(arrowAnchor)
        self.coordinator?.arrowAnchor = arrowAnchor
        arSceneView.session.delegate = self.coordinator
                
        
        guard let configDebug = configDebug else {
            print("Error: configDebug es nil")
            return
        }
                
        setupAndUpdateConfigDebug(arSceneView: arSceneView)
        let destinationPoiName = self.destinationPoiName ?? ""
        self.coordinator?.setDestinationPoi(destinationPoiName: destinationPoiName)
                
               
    }    
 
    func adjustVisibilityBasedOnDistance(arSceneView: CustomARSceneView, mainAnchor: AnchorEntity, nearDistance: Float, farDistance: Float) {
        let cameraPosition = arSceneView.cameraTransform.translation

        for child in mainAnchor.children {
            // Calculate the distance between the camera and each child of the main anchor
            let distance = simd_distance(cameraPosition, child.transform.translation)
            
            // Filter visibility based on distance
            if distance < nearDistance || distance > farDistance {
                child.isEnabled = false // Turn off object visibility
            } else {
                child.isEnabled = true // Turn on object visibility
            }
        }
    }

    
    deinit {
        updateTimer?.invalidate()
    }

    
    func setupFixedAnchor(arSceneView: CustomARSceneView) {
        
        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        arSceneView.scene.anchors.append(fixedAnchor)
        self.mainAnchor = fixedAnchor
    }
    
    func makeCoordinator() -> Coordinator {
        let locationManager = LocationManager()
        let coordinator = Coordinator(locationManager: locationManager)
        coordinator.arSceneHandler = self // Assign the ARSceneHandler to the Coordinator
        return coordinator
    }


    /**
     Called once per frame.
     */
    func session(_ session: ARSession, didUpdate frame: ARFrame) {        
        //self.coordinator.handlePointUpdate()
        //self.coordinator.handleLocationUpdate()
    }
    
    func handleFrameUpdate(frame: ARFrame) {
      
        guard let configParameters = configDebug?.getConfigParameters(),
              let arrowDistance = configParameters["arrowDistance"],
              let cameraDepth = configParameters["cameraDeph"] else {
            print("Error: Could not get arrowDistance or cameraDeph from configuration parameters")
            return
        }
        
        coordinator?.setArrowDistance(arrowDistance: arrowDistance)
        self.cameraDeph = Double(cameraDepth)

        let hasToReset = configDebug?.hasToReset ?? false

        if hasToReset {
            coordinator?.updatePOIs()
            configDebug?.disableHasToReset()
        }
        
        if let hiddenPanelInfo = configParameters["HiddenPanelInfo"] {
            self.coordinator?.isDebugEnabled = hiddenPanelInfo == 1.0
        }

    }
    
    //Update AR
    
    func updateRefreshing() {
        
        hasToRefresh = true
        
        if let arQuality = arQuality {
            hasToRefresh = arQuality.hasToResetWorld()
        } else {
            hasToRefresh = false
        }
        
        if hasToResetChangeFloor{
            hasToRefresh = true
        }
        
        if hasToRefresh {
            let numRefresh = 1
            startRefreshing(numRefresh)
        } else if refreshingTimer > 0 {
            refresh()
            refreshingTimer -= 1
            if refreshingTimer == 0 {
                stopRefreshing()
            }
        }
        
        coordinator?.setHasToReset(hasToRefresh: hasToRefresh)
    }
    
    func refresh() {
        let currentTimestamp = Int(Date().timeIntervalSince1970 * 1000) // Time in miliseconds
        if currentTimestamp > timestampLastRefresh + 5000 {
            if let coordinator = self.coordinator {                
                coordinator.updatePOIs()
            }
            timestampLastRefresh = currentTimestamp
        }
    }

    func setupAndUpdateConfigDebug(arSceneView: CustomARSceneView){
        
        guard let configDebug = configDebug else {
            print("Error: configDebug es nil")
            return
        }
        
        configDebug.setupUpdateDebugInfo(view: arSceneView)
        configDebug.setupInfoPanel(view: arSceneView) // Setting information panel
        configDebug.startRefreshingInfo()
    }

    func startRefreshing(_ numRefresh: Int) {
        refresh()
        refreshingTimer = numRefresh
    }
    
    func stopRefreshing() {
        /*ARModeDebugValues.refresh.value = false
        _unityViewController?.send("MessageManager", methodName: "SendRefressData", message: "1000000")*/
    }


    func updateArQuality(location: SITLocation) {
        
        updateRefreshing()
        arQuality?.updateSitumLocation(location: location)
        
        // Unpacking optional camera coordinate values
        if let worldPosition = coordinator?.arView?.cameraTransform.translation,
           let worldRotation = coordinator?.arView?.cameraTransform.rotation {
  
            let position: SCNVector3 = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z)
            let rotation = SCNQuaternion(worldRotation.axis.x,
                                         worldRotation.axis.y,
                                         worldRotation.axis.z,
                                         worldRotation.angle)
            arQuality?.updateARLocation(worldPosition: position, worldRotation: rotation)
            self.setSitArData()
            
        } else {
            print("Error: no se pudieron obtener los valores de la cámara")
        }
    }

    
    // Finish update AR
    
    // MARK: Communication Manager callbacks:
    
    func onBuildingInfoReceived(_ buildingInfo: SITBuildingInfo?, withError error: Error?) {
        if let coordinator = self.coordinator, let indoorPois = buildingInfo?.indoorPois {
            // Pois parse
            let poisMapArray = parsePois(pois: indoorPois)
            // Wrap the array in a dictionary before passing it to updatePOIs
            let poisMap: [String: Any] = ["pois": poisMapArray]
            // Call to updatePOIs to update pois position
            coordinator.handlePoisUpdated(poisMap: poisMap)
        } else {
            print("Coordinator is nil or no POIs available")
        }
    }

    
    // MARK: LocationManager delegate.
    
    func locationManager(_ locationManager: any SITLocationInterface, didUpdate location: SITLocation) {
        
        if let coordinator = self.coordinator {
            print("Situm> Location received!! and send to AR: \(location)")
            coordinator.handleLocationUpdate(location: location)
            updateArQuality(location: location)
            resfreshByChangeFloor(location: location, currentIndex: &currentIndex, hasToResetChangeFloor: &hasToResetChangeFloor, locationBuffer: &locationsBuffer)

        } else {
            print("Coordinator is nil")
        }
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didFailWithError error: (any Error)?) {
        print("Situm> Location encountered an error: \(error?.localizedDescription ?? "Unknown error")")
    }
    
    func locationManager(_ locationManager: any SITLocationInterface, didUpdate state: SITLocationState) {
        print("Situm> Location state changed: \(state)")
    }
    
    // MARK: NavigationManager delegate.
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didStartOn route: SITRoute) {
        print("Situm> Navigation started on route: \(route.toDictionary()["points"])")
        staticRoute = route.toDictionary()["points"] as? [[String: Any]] ?? []
        self.destinationPoiName = route.poiTo.name
        
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didFailWithError error: Error) {
        print("Situm> Navigation encountered an error: \(error.localizedDescription)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didUpdate progress: SITNavigationProgress, on route: SITRoute) {
        if let coordinator = self.coordinator {
            coordinator.handlePointUpdate(route.toDictionary()["points"])
        } else {
            print("Coordinator is nil")
        }
        
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, destinationReachedOn route: SITRoute) {
        print("Situm> Destination reached on route: \(route)") 
        delegate?.didReachDestination()

        
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, userOutsideRoute route: SITRoute) {
        print("Situm> User is outside the route: \(route)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didCancelOn route: SITRoute) {
        print("Situm> Navigation cancelled on route: \(route)")
    }
    
    
    func setSitArData() {
        guard let worldPosition = coordinator?.arView?.cameraTransform.translation else {
            print("Error: Failed to get camera position.")
            return
        }

        let currentTimestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        if lastTimestamp != 0 {
            guard let sitArData = self.sitArData else {
                print("Error: sitArData is not initialized.")
                return
            }

            sitArData.dt = Float(currentTimestamp - lastTimestamp)
            sitArData.x = Float(worldPosition.x)
            sitArData.y = Float(worldPosition.y)
            sitArData.z = -1.0*Float(worldPosition.z)
            sitArData.timestamp = Double(currentTimestamp)

            // Get the current frame
            guard let frame = coordinator?.arView?.session.currentFrame else {
                print("Error: No se pudo obtener el frame actual de la sesión.")
                return
            }

            // Get the camera transformation matrix
            let cameraTransform = frame.camera.transform

            // Calculate Euler angles from the transformation matrix
            let eulerAngles = cameraTransform.eulerAngles()
            
            sitArData.xEuler = Float(eulerAngles.x) // Roll
            sitArData.yEuler = Float(eulerAngles.y) // Pitch
            sitArData.zEuler = Float(eulerAngles.z) // Yaw

            sitExternalSensorManager?.setArData(sitArData)
        }
        
        lastTimestamp = currentTimestamp
    }

    
    func didEnteredGeofences(_ geofences: [SITGeofence]!) {
        print("ARSceneHandler - Entered geofences: \(geofences)")
        self.currentGeofences = geofences ?? []
        
        guard let coordinator = self.coordinator,
              let arView = coordinator.arView,
              let mainAnchor = mainAnchor else {
            return
        }

        // Load dynamic models
        coordinator.modelManager.loadDynamicsModels(geofences: geofences, arView: arView, mainAnchor: mainAnchor)
       
    }

    func didExitedGeofences(_ geofences: [SITGeofence]!) {
        print("ARSceneHandler - Exit from geofences: \(geofences)")
        
        guard let coordinator = self.coordinator,
              let arView = coordinator.arView,
              let mainAnchor = mainAnchor else {
            return
        }

        // Remove all models
        coordinator.modelManager.removeDynamicModels( arView: arView, geofences: geofences)
    }



}
