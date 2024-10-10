import Foundation
import ARKit

/**
 * Plugin controller.
 */
@available(iOS 14.0, *)
class ARController: NSObject {
    
    private let arView: SitumARPlatformView
    private let arSceneHandler: ARSceneHandler
    private let arMethodCallSender: ARMethodCallSender

    private var isLoaded = false
    private var isLoading = false

    init(arView: SitumARPlatformView, arSceneHandler: ARSceneHandler, arMethodCallSender: ARMethodCallSender) {
        self.arView = arView
        self.arSceneHandler = arSceneHandler
        self.arMethodCallSender = arMethodCallSender
        super.init()
    }
    
    // Cargar AR
    func load(/*TODO: meter building ID*/) {
        print("Situm> AR> L&U> CALLED LOAD")
        if isLoaded || isLoading {
            return
        }
        print("Situm> AR> L&U> ACTUALLY LOADED")
        isLoading = true
        arView.load()

        arSceneHandler.setupSceneView(arSceneView: arView.sceneView)
        
        // TODO: start loading building & POIs, delegate them to arSceneHandler.

        isLoaded = true
        isLoading = false
    }
    
    // Descargar AR
    func unload() {
        print("Situm> AR> L&U> CALLED UNLOAD")
        if isLoaded {
            print("Situm> AR> L&U> ACTUALLY UNLOADED")
            arView.unload()
            isLoading = false
            isLoaded = false
        }
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
