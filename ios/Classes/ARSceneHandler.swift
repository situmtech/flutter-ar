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
    
    var arQuality: ARQuality?
    var refreshingTimer = 5
    var timestampLastRefresh = 0
    
    func setupSceneView(arSceneView: CustomARSceneView) {

        arSceneView.cameraMode = .ar
        arSceneView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        configuration.planeDetection = []
        arSceneView.session.run(configuration)
        
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
        
        setupUpdatePOIsButton(view: arSceneView)

               
    }
    
    func setupUpdatePOIsButton(view: UIView) {
            // Crear el botón
            updateButton = UIButton(type: .system)
            updateButton?.setTitle("Update POIs", for: .normal)
            updateButton?.frame = CGRect(x: 20, y: 50, width: 150, height: 50)
            updateButton?.backgroundColor = .systemBlue
            updateButton?.setTitleColor(.white, for: .normal)
            updateButton?.layer.cornerRadius = 10

            // Añadir la acción del botón
            updateButton?.addTarget(self, action: #selector(updatePOIsButtonTapped), for: .touchUpInside)

            // Añadir el botón a la vista principal
            if let button = updateButton {
                view.addSubview(button)
            }
        }
        
        // Acción cuando se pulsa el botón
        @objc func updatePOIsButtonTapped() {
            print("Update POIs button tapped!")
            if let coordinator = self.coordinator {
                print("Update POIs button tapped?!")
                coordinator.updatePOIs()
            }
        }

    
    
    func setupFixedAnchor(arSceneView: CustomARSceneView) {
        
        let fixedAnchor = AnchorEntity(world: SIMD3<Float>(0.0, 0.0, 0.0))
        fixedAnchor.name = "fixedPOIAnchor"

        arSceneView.scene.anchors.append(fixedAnchor)
        //self.fixedAnchor = fixedAnchor
    }
    
    func makeCoordinator() -> Coordinator {
        let locationManager = LocationManager()
        return Coordinator(locationManager: locationManager)
    }


    /**
     Called once per frame.
     */
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        //self.coordinator.handlePointUpdate()
        //self.coordinator.handleLocationUpdate()   
    }
    
    
    
    //Update AR
    
    func updateRefreshing() {
        var hasToRefresh = true
        guard let arPosQualityState = arQuality else {
            return
        }
        
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
                coordinator.updatePOIs()
            }
            timestampLastRefresh = currentTimestamp
        }
    }

    

    func startRefreshing(_ numRefresh: Int) {
        //ARModeDebugValues.refresh.value = true
        refresh()
        refreshingTimer = numRefresh
    }
    
    func stopRefreshing() {
        /*ARModeDebugValues.refresh.value = false
        _unityViewController?.send("MessageManager", methodName: "SendRefressData", message: "1000000")*/
    }


    func updateArQuality(location: SITLocation) {
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
}
