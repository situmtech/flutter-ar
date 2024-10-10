import Flutter
import Foundation


@available(iOS 14.0, *)
public class SitumArPlugin: NSObject, FlutterPlugin {
    var poisMap: [String: Any] = [:]

    public static func register(with registrar: FlutterPluginRegistrar) {
        let factory = ARViewFactory(messenger: registrar.messenger())
        registrar.register(factory, withId: "SitumARView")
    }
}

@available(iOS 14.0, *)
class ARViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        return SitumARPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }
}
