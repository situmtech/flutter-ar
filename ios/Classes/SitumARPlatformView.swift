import SwiftUI
import RealityKit
import ARKit
import Flutter


/**
 Situm Platform View implementation for AR.
 */
@available(iOS 15.0, *)
class SitumARPlatformView: NSObject, FlutterPlatformView {
    
    private var rootView: UIView
    var sceneView: CustomARSceneView
    
    @available(iOS 15.0, *)
    init(frame: CGRect,
         viewIdentifier viewId: Int64,
         arguments args: Any?,
         messenger: FlutterBinaryMessenger) {
        
        rootView = UIView(frame: frame)
        sceneView = CustomARSceneView(frame: .zero)
        
        super.init()
        
        // TODO: FER: o method channel podemos construílo no plugin e pasarllo aquí a través do factory.
        let flutterMethodChannel = FlutterMethodChannel(name: "SitumARView", binaryMessenger: messenger)
        let arMethodCallSender = ARMethodCallSender(methodChannel: flutterMethodChannel)
        let sceneHandler = ARSceneHandler()
        let arController = ARController(arView: self, arSceneHandler: sceneHandler, arMethodCallSender: arMethodCallSender)
        let arMethodCallHandler = ARMethodCallHandler(arController: arController)
        
        flutterMethodChannel.setMethodCallHandler { (call, result) in
            let arguments = call.arguments as? [String: Any] ?? [:]
            arMethodCallHandler.handle(method: call.method, arguments: arguments, result: result)
        }
        
        // TODO: debug
        // sceneView.debugOptions = [.showFeaturePoints, .showWorldOrigin]
        sceneView.session.delegate = sceneHandler
    }
    
    func load() {
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        configuration.worldAlignment = .gravity
        
        sceneView.session.run(configuration)
        
        sceneView.frame = rootView.bounds
        sceneView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        rootView.addSubview(sceneView)
    }
    
    func unload() {
        sceneView.session.pause()
        sceneView.removeFromSuperview()
    }
    
    func view() -> UIView {
        return rootView
    }
    
    deinit {
        unload()
    }
}
