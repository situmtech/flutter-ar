part of 'ar.dart';

class ARController {
  static ARController? _instance;

  _ARWidgetState? _widgetState;
  MapViewController? _mapViewController;

  final MethodChannel _channel = const MethodChannel(CHANNEL_ID);

  ARController._() {
    SitumSdk().internalSetMethodCallARDelegate(_methodCallHandler);
  }

  factory ARController() {
    _instance ??= ARController._();
    return _instance!;
  }

  /// Let this ARController be up to date with the AR Widget State.
  void _onARWidgetState(_ARWidgetState? state) {
    _widgetState = state;
  }

  /// Notifies the AR module that the MapView has been loaded, ensuring seamless
  /// integration between both.
  void onMapViewLoad(MapViewController controller) {
    _mapViewController = controller;
    controller.internalARMessageDelegate(_onMapViewMessage);
    debugPrint("Situm> AR> onMapViewLoad");
  }

  // === Internal MapViewer messages:

  void _onMapViewMessage(String message, dynamic payload) {
    switch (message) {
      case WV_MESSAGE_AR_REQUESTED:
        debugPrint("Situm> AR> WV_MESSAGE_AR_REQUESTED");
        onArRequested();
        break;
    }
  }

  // === Sleep/Wake actions:

  Future<void> onArRequested() async {
    _widgetState?.updateStatusArRequested();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.success);
    _mapViewController?.followUser();
    Future.delayed(_ARWidgetState.animationDuration, () {
      // Repeat the call to followUser after the animation, as it seems possible
      // to move the map during that time interval.
      _mapViewController?.followUser();
    });
    // Notify the client callback:
    _widgetState?.widget.onARVisibilityChanged?.call(ARVisibility.visible);
    await load(); // Safe call, even if the AR is already loaded.
    await resume();
  }

  Future<void> onArGone() async {
    await pause();
    // TODO: optimize native side so the AR can be completely unloaded.
    // await unload();
    _widgetState?.updateStatusArGone();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.finished);
    _widgetState?.widget.onARVisibilityChanged?.call(ARVisibility.gone);
  }

  Future<void> pause() async {
    debugPrint("Situm > AR> Pause AR.");
    await _channel.invokeMethod("pause", {});
  }

  Future<void> resume() async {
    debugPrint("Situm > AR> Resume AR.");
    await _channel.invokeMethod("resume", {});
  }

  Future<void> unload() async {
    debugPrint("Situm > AR> Unload AR.");
    await _channel.invokeMethod("unload", {});
  }

  Future<void> load() async {
    debugPrint("Situm > AR> Load AR.");
    await _channel.invokeMethod("load", {});
  }

  // === Set of methods to keep the AR module updated regarding position and navigation.
  Future<void> _methodCallHandler(InternalCall call) async {
    // TODO: restore.
    switch (call.type) {
      case InternalCallType.location:
        // _onLocationChanged(call.get());
        break;
      case InternalCallType.navigationStart:
        // _onNavigationStart(call.get());
        break;
      case InternalCallType.navigationDestinationReached:
        // _onNavigationDestinationReached();
        break;
      case InternalCallType.navigationProgress:
        // _onNavigationProgress(call.get());
        break;
      case InternalCallType.navigationOutOfRoute:
        // _onNavigationOutOfRoute();
        break;
      case InternalCallType.navigationCancellation:
        // _onNavigationCancelled();
        break;
      case InternalCallType.geofencesEnter:
        // _onEnterGeofences(call.get());
        break;
      case InternalCallType.geofencesExit:
        // _onExitGeofences(call.get());
        break;
      default:
        debugPrint("Unhandled call: ${call.type}");
        break;
    }
  }
}
