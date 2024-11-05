import Foundation
import ARKit
import RealityKit
import SitumSDK

/**
 ARSceneJuandler. Manage AR world.
 */
@available(iOS 15.0, *)
class ARSceneHandler: NSObject, ARSessionDelegate, SITLocationDelegate, SITNavigationDelegate {  


    var coordinator: Coordinator?   
    
    var arQuality: ARQuality?
    var configDebug: ConfigDebug?
    var refreshingTimer = 5
    var timestampLastRefresh = 0
    var hasToRefresh = true
    var currentAlert: UIAlertController?
    
    var mainAnchor: AnchorEntity? // Declara mainAnchor como propiedad de la clase
    var updateTimer: Timer?
    var cameraDeph = 25.0
    
    var sitArData: SITArData?
    var lastTimestamp = 0
    var sitExternalSensorManager: SITExternalSensorManager?
    
    var locationsBuffer: [String?] = Array(repeating: nil, count: 10)
    var currentIndex = 0 // Índice para controlar la posición de inserción
    var hasToResetChangeFloor = false
    
    
    func setupSceneView(arSceneView: CustomARSceneView) {

        arSceneView.cameraMode = .ar
        arSceneView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arSceneView.session.run(configuration)
        
   
        addLightToScene(arView: arSceneView)
         
        arQuality = ARQuality()
        sitArData = SITArData()
        sitExternalSensorManager = SITExternalSensorManager()
     
        configDebug = ConfigDebug(arQuality: arQuality, hasToRefresh: hasToRefresh)

        //Fija un ancla en el origen de coordenadas
        setupFixedAnchor(arSceneView: arSceneView)
        
        // Agregar la luz direccional
        addDirectionalLight(to: arSceneView)
        
        // Inicializa el temporizador para ajustar la visibilidad de los objetos en función de la distancia
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let mainAnchor = self.mainAnchor else { return }
            self.adjustVisibilityBasedOnDistance(arSceneView: arSceneView, mainAnchor: mainAnchor, nearDistance: 0.1, farDistance: Float(cameraDeph))
        }
        
        //Arrow
        let arrowAnchor = createArrowAnchor()
        arSceneView.scene.anchors.append(arrowAnchor)
        /*context.coordinator.arrowAnchor = arrowAnchor*/
        
        //Setup animated model
        //let fixedAnchorModel = setupDynamicModel()
        //arSceneView.scene.anchors.append(fixedAnchorModel)
     
        
        // Instancia el Coordinator
        self.coordinator = makeCoordinator()
        self.coordinator?.arView = arSceneView // Asigna la vista AR
        self.coordinator?.arrowAnchor = arrowAnchor // Asigna el ancla de la flecha
        arSceneView.session.delegate = self.coordinator
        
                
        guard let configDebug = configDebug else {
            print("Error: configDebug es nil")
            return
        }
        
        
        setupAndUpdateConfigDebug(arSceneView: arSceneView)
        
        
               
    }    
 
    func adjustVisibilityBasedOnDistance(arSceneView: CustomARSceneView, mainAnchor: AnchorEntity, nearDistance: Float, farDistance: Float) {
        let cameraPosition = arSceneView.cameraTransform.translation

        for child in mainAnchor.children {
            // Calcula la distancia entre la cámara y cada hijo del ancla principal
            let distance = simd_distance(cameraPosition, child.transform.translation)
            
            // Filtrar la visibilidad basada en la distancia
            if distance < nearDistance || distance > farDistance {
                child.isEnabled = false // Desactivar la visibilidad del objeto
            } else {
                child.isEnabled = true // Activar la visibilidad del objeto
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
        coordinator.arSceneHandler = self // Asigna el ARSceneHandler al Coordinator
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
        //print("Actualiza en cada frame desde el Coordinator")
        guard let configParameters = configDebug?.getConfigParameters(),
              let arrowDistance = configParameters["arrowDistance"],
              let cameraDepth = configParameters["cameraDeph"] else {
            print("Error: No se pudo obtener arrowDistance o cameraDeph de los parámetros de configuración")
            return
        }
        
        coordinator?.setArrowDistance(arrowDistance: arrowDistance) // Asegúrate de que el tipo sea correcto
        self.cameraDeph = Double(cameraDepth) // Asegúrate de que cameraDepth esté en el tipo correcto
        //print("camera deph  a", self.cameraDeph)

        let hasToReset = configDebug?.hasToReset ?? false

        if hasToReset {
            coordinator?.updatePOIs()
            configDebug?.disableHasToReset()
        }
        
        if let hiddenPanelInfo = configParameters["HiddenPanelInfo"] {
            self.coordinator?.isDebugEnabled = hiddenPanelInfo == 1.0
        }
       

    }

    
    func infoDebug(){
        if let coordinator = self.coordinator {
            if let viewController = coordinator.arView?.window?.rootViewController {
                showAlert(message: "hasToRefresh: \(hasToRefresh)", on: viewController)
            }
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
    }
    
    func refresh() {
        let currentTimestamp = Int(Date().timeIntervalSince1970 * 1000) // Obtener el timestamp en milisegundos
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
        configDebug.setupInfoPanel(view: arSceneView) // Crear el panel de información
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
        

        // Desempaquetar los valores opcionales de coordenadas de cámara
        if let worldPosition = coordinator?.arView?.cameraTransform.translation,
           let worldRotation = coordinator?.arView?.cameraTransform.rotation {
            
            // Asegurar que los tipos están correctos: SCNVector3 y SCNQuaternion
            let position: SCNVector3 = SCNVector3(worldPosition.x, worldPosition.y, worldPosition.z)
            let rotation = SCNQuaternion(worldRotation.axis.x,
                                         worldRotation.axis.y,
                                         worldRotation.axis.z,
                                         worldRotation.angle)
            arQuality?.updateARLocation(worldPosition: position, worldRotation: rotation)
            
            //self.setSitArData()
        } else {
            print("Error: no se pudieron obtener los valores de la cámara")
        }
    }

    
    // Finish update AR
    
    // MARK: Communication Manager callbacks:
    
    func onBuildingInfoReceived(_ buildingInfo: SITBuildingInfo?, withError error: Error?) {
       // print("Situm> Got \(buildingInfo?.indoorPois.count ?? 0) POIs: \(String(describing: buildingInfo?.indoorPois))")
        
        if let coordinator = self.coordinator, let indoorPois = buildingInfo?.indoorPois {
            // Parsea los POIs
            let poisMapArray = parsePois(pois: indoorPois)
            // Envuelve el array en un diccionario antes de pasarlo a updatePOIs
            let poisMap: [String: Any] = ["pois": poisMapArray]
            // Llama a updatePOIs con el diccionario
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
        print("Situm> Navigation started on route: \(route)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didFailWithError error: Error) {
        print("Situm> Navigation encountered an error: \(error.localizedDescription)")
    }
    
    func navigationManager(_ navigationManager: SITNavigationInterface, didUpdate progress: SITNavigationProgress, on route: SITRoute) {
        //print("Situm> Progress updated on route: \(route.toDictionary()["points"]), progress: \(progress)")
        if let coordinator = self.coordinator {
            coordinator.handlePointUpdate(route.toDictionary()["points"])
        } else {
            print("Coordinator is nil")
        }
        
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
    
    
    
    func showAlert(message: String, on viewController: UIViewController) {
            let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            viewController.present(alert, animated: true, completion: nil)

            // Duración de la alerta (en segundos)
            let duration: Double = 2.0

            // Cerrar la alerta después de `duration` segundos
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    
    func setSitArData() {
        guard let worldPosition = coordinator?.arView?.cameraTransform.translation else {
            print("Error: No se pudo obtener la posición de la cámara.")
            return
        }

        let currentTimestamp = Int(Date().timeIntervalSince1970 * 1000)
        
        if lastTimestamp != 0 {
            // Asegúrate de que sitArData no sea nil
            guard var sitArData = self.sitArData else {
                print("Error: sitArData no está inicializado.")
                return
            }

            sitArData.dt = Float(currentTimestamp - lastTimestamp)
            print("delta dt:   ", sitArData.dt)
            sitArData.x = Float(worldPosition.x)
            sitArData.y = Float(worldPosition.y)
            sitArData.z = -1.0*Float(worldPosition.z)
            sitArData.timestamp = Double(currentTimestamp)

            // Obtener el frame actual
            guard let frame = coordinator?.arView?.session.currentFrame else {
                print("Error: No se pudo obtener el frame actual de la sesión.")
                return
            }

            // Obtener la matriz de transformación de la cámara
            let cameraTransform = frame.camera.transform

            // Calcular los ángulos de Euler a partir de la matriz de transformación
            let eulerAngles = cameraTransform.eulerAngles()
            
            sitArData.xEuler = Float(eulerAngles.x) // Roll
            sitArData.yEuler = Float(eulerAngles.y) // Pitch
            sitArData.zEuler = Float(eulerAngles.z) // Yaw

            // Llama a setArData sin la etiqueta
            sitExternalSensorManager?.setArData(sitArData) // Aquí se pasa sitArData directamente
        }
        
        lastTimestamp = currentTimestamp
    }


}
