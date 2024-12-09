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
    
    // Method to send messages to Dart when or AR must be stopped
    func sendArGoneRequired() {
        let arguments: [String: Any] = ["reason": "lifecycle_stop"]
        methodChannel.invokeMethod("ArGoneRequired", arguments: arguments)
    }
}
