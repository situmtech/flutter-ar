import Foundation
import ARKit
import RealityKit
import SitumSDK

/**
 ARSceneJuandler. Manage AR world.
 */
@available(iOS 15.0, *)
class ARSceneHandler: NSObject, ARSessionDelegate, SITLocationDelegate, SITNavigationDelegate {
  
    /**
     Called once after initialization.
     */

    var coordinator: Coordinator?
    
    var updateButton: UIButton?
    var infoPanel: UIView?
    var infoLabel: UILabel?
    var isInfoVisible = false
    var refreshTimer: Timer?
    var infoLabel1: UILabel?
    var infoLabel2: UILabel?
    var infoLabel3: UILabel?
    var infoLabel4: UILabel?
    var infoLabel5: UILabel?

    
    
    var arQuality: ARQuality?
    var refreshingTimer = 5
    var timestampLastRefresh = 0
    var hasToRefresh = true
    var currentAlert: UIAlertController?
    
    
    func setupSceneView(arSceneView: CustomARSceneView) {

        arSceneView.cameraMode = .ar
        arSceneView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arSceneView.session.run(configuration)
        
         
        arQuality = ARQuality()
        
        //Fija un ancla en el origen de coordenadas
        setupFixedAnchor(arSceneView: arSceneView)
        
        // Agregar la luz direccional
        addDirectionalLight(to: arSceneView)
        
        //Arrow
        let arrowAnchor = createArrowAnchor()
        arSceneView.scene.anchors.append(arrowAnchor)
        /*context.coordinator.arrowAnchor = arrowAnchor*/
        
        //Setup animated model
        let fixedAnchorModel = setupDynamicModel()
        arSceneView.scene.anchors.append(fixedAnchorModel)
     
        
        // Instancia el Coordinator
        self.coordinator = makeCoordinator()
        self.coordinator?.arView = arSceneView // Asigna la vista AR
        self.coordinator?.arrowAnchor = arrowAnchor // Asigna el ancla de la flecha
        arSceneView.session.delegate = self.coordinator
        
        setupUpdateDebugInfo(view: arSceneView)
        setupInfoPanel(view: arSceneView) // Crear el panel de información
        startRefreshingInfo()
               
    }
    
    
    
////Panel info debug
    
    
    // Función para crear el botón de Toggle Info
        func setupUpdateDebugInfo(view: UIView) {
            // Crear el botón
            updateButton = UIButton(type: .system)
            updateButton?.setTitle("Info Debug", for: .normal)
            updateButton?.frame = CGRect(x: 20, y: 20, width: 100, height: 30)
            updateButton?.backgroundColor = .systemBlue
            updateButton?.setTitleColor(.white, for: .normal)
            updateButton?.layer.cornerRadius = 10

            // Añadir la acción del botón
            updateButton?.addTarget(self, action: #selector(toggleInfoDebug), for: .touchUpInside)

            // Añadir el botón a la vista principal
            if let button = updateButton {
                view.addSubview(button)
            }
        }

        // Crear el panel de información y configuración
    func setupInfoPanel(view: UIView) {
 
            infoPanel = UIView(frame: CGRect(x: 10, y: 50, width: view.frame.width - 40, height: 300))
            infoPanel?.backgroundColor = .clear
            infoPanel?.layer.cornerRadius = 10
            infoPanel?.layer.borderWidth = 2
            infoPanel?.layer.borderColor = UIColor.lightGray.cgColor

            infoLabel1 = UILabel(frame: CGRect(x: 10, y: 10, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel1?.textAlignment = .left
            infoLabel1?.textColor = .gray
            infoPanel?.addSubview(infoLabel1!)

            infoLabel2 = UILabel(frame: CGRect(x: 10, y: 30, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel2?.textAlignment = .left
            infoLabel2?.textColor = .gray
            infoPanel?.addSubview(infoLabel2!)

            infoLabel3 = UILabel(frame: CGRect(x: 10, y: 50, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel3?.textAlignment = .left
            infoLabel3?.textColor = .gray
            infoPanel?.addSubview(infoLabel3!)

            infoLabel4 = UILabel(frame: CGRect(x: 10, y: 70, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel4?.textAlignment = .left
            infoLabel4?.textColor = .gray
            infoPanel?.addSubview(infoLabel4!)

            infoLabel5 = UILabel(frame: CGRect(x: 10, y: 90, width: infoPanel!.frame.width - 20, height: 20))
            infoLabel5?.textAlignment = .left
            infoLabel5?.textColor = .gray
            infoPanel?.addSubview(infoLabel5!)

            // Sección de configuración
            let configLabel = UILabel(frame: CGRect(x: 10, y: 110, width: 200, height: 20))
            configLabel.text = "Activar Configuración:"
            configLabel.textColor = .gray
            infoPanel?.addSubview(configLabel)

            let configSwitch = UISwitch(frame: CGRect(x: infoPanel!.frame.width - 70, y: 110, width: 50, height: 30))
            configSwitch.isOn = false
            configSwitch.addTarget(self, action: #selector(configSwitchChanged(_:)), for: .valueChanged)
            infoPanel?.addSubview(configSwitch)

            // Agregar el panel a la vista pero inicialmente oculto
            if let panel = infoPanel {
                panel.isHidden = true
                view.addSubview(panel)
            }
        }

        // Función que se llama cuando se cambia el valor del switch de configuración
        @objc func configSwitchChanged(_ sender: UISwitch) {
            if sender.isOn {
                print("Configuración activada")
            } else {
                print("Configuración desactivada")
            }
        }

        // Función para alternar entre mostrar y ocultar el panel
        @objc func toggleInfoDebug() {
            if let panel = infoPanel {
                panel.isHidden = !panel.isHidden // Alterna la visibilidad
                isInfoVisible.toggle()
            }
        }

        // Función para iniciar el refresco de la información en tiempo real
        func startRefreshingInfo() {
            // Detener cualquier timer existente
            refreshTimer?.invalidate()
            
            // Crear un nuevo Timer que actualice la información cada 1 segundo
            refreshTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateInfoPanel), userInfo: nil, repeats: true)
        }

        // Función que actualiza la información mostrada en el panel
    @objc func updateInfoPanel() {
        
        guard let arQuality = arQuality else {
            print("Error: arQuality es nil")
            return
        }
        
        // Obtener la información actualizada de arQuality
        let infoDebug = arQuality.getInfoParameters()
        
        guard let globalQuality = infoDebug["globalQuality"] as? Double else {
            print("Error: global quality es nil o no es un Double")
            return
        }
        
        let roundedQuality = (globalQuality * 100).rounded() / 100

        // Actualizar las etiquetas con los nuevos valores
        infoLabel1?.text = "HasToRefresh: \(hasToRefresh)"
        infoLabel2?.text = "GlobalQuality: \(roundedQuality)"
        infoLabel3?.text = "DynamicRefreshThreshold: \(infoDebug["DynamicRefreshThreshold"])"
        infoLabel4?.text = "ArConf: \(infoDebug["arConf"])"
        infoLabel5?.text = "SitumConf: \(infoDebug["situmConf"])"
            
            
            
        }

        // Detener el refresco cuando no sea necesario
        func stopRefreshingInfo() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    
    
    
    
    
    
    
    
    
///Fin panel info debug
    
    
    func setupFixedAnchor(arSceneView: CustomARSceneView) {
        
        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        arSceneView.scene.anchors.append(fixedAnchor)
        //self.fixedAnchor = fixedAnchor
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
        print("Actualiza en cada frame desde el Coordinator")
        //showInfoDebug()
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
             /*   if let viewController = coordinator.arView?.window?.rootViewController {
                   
                    showAlert(message: "Refresh!", on: viewController)
                }*/
                
                coordinator.updatePOIs()
            }
            timestampLastRefresh = currentTimestamp
        }
    }

    

    func startRefreshing(_ numRefresh: Int) {
        //ARModeDebugValues.refresh.value = true
       /* if let viewController = coordinator?.arView?.window?.rootViewController {
            showAlert(message: "Update POIs button tapped!", on: viewController)
        }
        print("Start Resfresss!!!!!")*/
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
        print("Situm> Progress updated on route: \(route.toDictionary()["points"]), progress: \(progress)")
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
}
