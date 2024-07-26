import Flutter
import UIKit

public class SitumArPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "situm_ar", binaryMessenger: registrar.messenger())
    let instance = SitumArPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
      let factory = FLNativeViewFactory(messenger: registrar.messenger())
      registrar.register(factory, withId: "<my-lag-progress-view>")
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
