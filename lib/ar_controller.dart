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

  void onArRequested() {
    resume();
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
  }

  void onArGone() {
    _widgetState?.updateStatusArGone();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.finished);
    pause();
    _widgetState?.widget.onARVisibilityChanged?.call(ARVisibility.gone);
  }
  

  void pause() async {
    await _channel.invokeMethod("pause", {});
  }

  void resume() async {
    await _channel.invokeMethod("resume", {});
  }

  // === Set of methods to keep the AR module updated regarding position and navigation.
  Future<void> _methodCallHandler(InternalCall call) async {
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

  Future<void> unload() async {
    await _channel.invokeMethod("unload", {});
  }

  Future<void> load() async {
    await _channel.invokeMethod("load", {});
  }
}
