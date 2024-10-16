import Foundation
import ARKit
import SitumSDK

/**
 * Plugin controller.
 */
@available(iOS 14.0, *)
class ARController: NSObject {
    
    private let arView: SitumARPlatformView
    private let arSceneHandler: ARSceneHandler
    private let arMethodCallSender: ARMethodCallSender
    private let sitLocationManager = SITLocationManager.sharedInstance()
    private let sitNavigationManager = SITNavigationManager.shared()
    private let sitCommManager = SITCommunicationManager.shared()
    
    private var isLoaded = false
    private var isLoading = false
    
    init(arView: SitumARPlatformView, arSceneHandler: ARSceneHandler, arMethodCallSender: ARMethodCallSender) {
        self.arView = arView
        self.arSceneHandler = arSceneHandler
        self.arMethodCallSender = arMethodCallSender
        super.init()
    }
    
    // Cargar AR
    func load(buildingIdentifier: String) {
        print("Situm> AR> L&U> CALLED LOAD for building \(buildingIdentifier)")
        if isLoaded || isLoading {
            return
        }
        print("Situm> AR> L&U> ACTUALLY LOADED")
        isLoading = true
        clearScene()
        arView.load()
        
        arSceneHandler.setupSceneView(arSceneView: arView.sceneView)
        
        // Subscribe to positioning/navigation callbacks:
        sitLocationManager.addDelegate(arSceneHandler)
        sitNavigationManager.addDelegate(arSceneHandler)
        
        // Start loading building & POIs, delegate them to arSceneHandler.
        sitCommManager.fetchBuildingInfo(buildingIdentifier, withOptions: nil, success: { (data) in
            self.arSceneHandler.onBuildingInfoReceived(data?["results"] as? SITBuildingInfo, withError: nil)
        }, failure: { (error) in
            self.arSceneHandler.onBuildingInfoReceived(nil, withError: error as Error?)
        })
        
        isLoaded = true
        isLoading = false
        return
    }
    
    // Descargar AR
    func unload() {
        print("Situm> AR> L&U> CALLED UNLOAD")
        if isLoaded {
            print("Situm> AR> L&U> ACTUALLY UNLOADED")
            sitLocationManager.removeDelegate(arSceneHandler)
            sitNavigationManager.removeDelegate(arSceneHandler)
            arView.unload()
            isLoading = false
            isLoaded = false
        }
    }
    
    private func clearScene() {
        // Asegúrate de limpiar todos los elementos de la escena antes de recargar
        arSceneHandler.coordinator?.arView?.scene.anchors.removeAll()
        arSceneHandler.coordinator?.resetFlags()
    }
    
    // Retomar AR
    func resume() {
        print("Situm> AR> L&U> CALLED RESUME")
        arView.load()
    }
    
    // Pausar AR
    func pause() {
        print("Situm> AR> L&U> CALLED PAUSE")
        arView.unload()
    }
    
    // -- TODO: check lifecycle calls:
    
    func onResume() {
        print("Situm> AR> L&U> Lifecycle> onResume")
    }
    
    func onPause() {
        print("Situm> AR> L&U> Lifecycle> onPause")
    }
    
    func onStop() {
        print("Situm> AR> L&U> Lifecycle> onStop")
        if isLoaded {
            arMethodCallSender.sendArGoneRequired()
        }
    }
}
