import Foundation
import Flutter

/**
 * MethodChannel wrapper/adapter. Use this class to communicate with the Dart side.
 */
class ARMethodCallSender {
    
    private let methodChannel: FlutterMethodChannel
    
    init(methodChannel: FlutterMethodChannel) {
        self.methodChannel = methodChannel
    }
    
    // Método para enviar mensaxes a Dart cando o AR debe ser detido
    func sendArGoneRequired() {
        let arguments: [String: Any] = ["reason": "lifecycle_stop"]
        methodChannel.invokeMethod("ArGoneRequired", arguments: arguments)
    }
}
