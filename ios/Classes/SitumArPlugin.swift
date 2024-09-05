import Flutter
import UIKit
import SwiftUI
import RealityKit
import ARKit
import CoreLocation

public class SitumArPlugin: NSObject, FlutterPlugin {
    var poisMap: [String: Any] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "situm_ar", binaryMessenger: registrar.messenger())
        let instance = SitumArPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Registrar la fábrica de la vista nativa
        let factory = ARViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "ARView")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "startARView":
            presentARView(result: result)
        case "updatePOIs":
            if let pois = call.arguments as? [String: Any] {
                poisMap = pois
                // Notify the ARView to update with new POIs
                NotificationCenter.default.post(name: .poisUpdated, object: nil)
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func presentARView(result: @escaping FlutterResult) {
        guard let viewController = UIApplication.shared.delegate?.window??.rootViewController else {
            result(FlutterError(code: "UNAVAILABLE", message: "Root view controller not available", details: nil))
            return
        }

        if #available(iOS 13.0, *) {
            let arView = UIHostingController(rootView: ContentView(poisMap: poisMap))
            viewController.present(arView, animated: true, completion: nil)
            result(nil)
        } else {
            result(FlutterError(code: "UNSUPPORTED_VERSION", message: "iOS version is lower than 13.0", details: nil))
        }
    }
}

extension Notification.Name {
    static let poisUpdated = Notification.Name("poisUpdated")
}

class ARViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return ARPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
    }
}

class ARPlatformView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, binaryMessenger: FlutterBinaryMessenger?) {
        if #available(iOS 13.0, *) {
            let arView = UIHostingController(rootView: ContentView(poisMap: [:])).view!
            arView.frame = frame
            _view = arView
        } else {
            _view = UIView()
        }
    }

    func view() -> UIView {
        return _view
    }
}
