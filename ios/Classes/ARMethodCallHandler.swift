import Foundation
import Flutter

@available(iOS 14.0, *)
class ARMethodCallHandler {
    
    private let controller: ARController
    
    init(arController: ARController) {
        self.controller = arController
    }
    
    // Constantes
    private let TAG = "Situm> AR>"
    private let DONE = "DONE"
    
    // Método para xestionar chamadas de métodos desde Dart
    func handle(method: String, arguments: [String: Any], result: @escaping FlutterResult) {        
        switch method {
        case "load":
            handleLoad(arguments: arguments, result: result)
        case "pause":
            handlePause(arguments: arguments, result: result)
        case "resume":
            handleResume(arguments: arguments, result: result)
        case "unload":
            handleUnload(arguments: arguments, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func handleLoad(arguments: [String: Any], result: @escaping FlutterResult) {
        let buildingIdentifer = arguments["buildingIdentifier"] as! String
        controller.load(buildingIdentifier: buildingIdentifer)
        result(DONE)
        print("\(TAG) ### AR has been LOADED and should be visible ###")
    }
    
    private func handleUnload(arguments: [String: Any], result: @escaping FlutterResult) {
        controller.unload()
        result(DONE)
        print("\(TAG) ### AR has been UNLOADED ###")
    }
    
    private func handleResume(arguments: [String: Any], result: @escaping FlutterResult) {
        controller.resume()
        result(DONE)
        print("\(TAG) ### AR has been RESUMED ###")
    }
    
    private func handlePause(arguments: [String: Any], result: @escaping FlutterResult) {
        controller.pause()
        result(DONE)
        print("\(TAG) ### AR has been PAUSED (camera should not be active) ###")
    }
}
