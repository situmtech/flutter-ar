import Flutter
import UIKit
import SwiftUI
import RealityKit
import ARKit
import CoreLocation
import Foundation

// Clase que maneja la lógica del plugin SitumAR
@objc(SitumARPlugin)
class SitumARPlugin: NSObject {
    
    @objc func updatePOIs(poisMap: [String: Any], width: Double) {
        // Enviar una notificación para actualizar los POIs en la vista AR
        NotificationCenter.default.post(name: .poisUpdated, object: nil, userInfo: ["poisMap": poisMap, "width": width])
        print("POIs updated from SitumARPlugin with data: \(poisMap)")
    }
    
    @objc func updateLocation(xSitum: Double, ySitum: Double, yawSitum: Double) {
        // Enviar una notificación para actualizar la ubicación en la vista AR
        NotificationCenter.default.post(name: .locationUpdated, object: nil, userInfo: ["xSitum": xSitum, "ySitum": ySitum, "yawSitum": yawSitum])
        print("Location updated from SitumARPlugin with xSitum: \(xSitum), ySitum: \(ySitum), yawSitum: \(yawSitum)")
    }
}

// Extensión para definir la notificación de actualización de POIs
extension Notification.Name {
    static let poisUpdated = Notification.Name("poisUpdated")
}

// Añadir a la extensión para la notificación de ubicación actualizada
extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
}

public class SitumArPlugin: NSObject, FlutterPlugin {
    var poisMap: [String: Any] = [:]
    var situmARPlugin = SitumARPlugin() // Instancia de la clase que contiene updateLocation

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
        case "updateLocation":
            if let args = call.arguments as? [String: Double],
               let xSitum = args["xSitum"],
               let ySitum = args["ySitum"],
               let yawSitum = args["yawSitum"] {
                let locationData: [String: Any] = [
                    "xSitum": xSitum,
                    "ySitum": ySitum,
                    "yawSitum": yawSitum
                ]
                NotificationCenter.default.post(name: .locationUpdated, object: nil, userInfo: locationData)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGUMENT", message: "Invalid arguments for updateLocation", details: nil))
            }
        case "updatePOIs":
            if let args = call.arguments as? [String: Any],
               let pois = args["pois"] as? [[String: Any]],
               let width = args["width"] as? Double {
                poisMap = ["pois": pois]
                var poisMapString = ""                
                if let poisMapData = try? JSONSerialization.data(withJSONObject: poisMap, options: .prettyPrinted),
                   let jsonString = String(data: poisMapData, encoding: .utf8) {
                    poisMapString = jsonString
                } else {
                    NSLog("Failed to convert POIs to JSON string")
                }
                
                print("POIs received: \(poisMapString)")
                NotificationCenter.default.post(name: .poisUpdated, object: nil, userInfo: ["poisMap": poisMap, "width": width])
            } else {
                NSLog("Failed to cast POIs or width. Received data: %@", String(describing: call.arguments))
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
