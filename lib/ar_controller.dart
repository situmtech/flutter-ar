part of 'ar.dart';

class ARController {
  static ARController? _instance;

  _ARWidgetState? _widgetState;
  _ARPosQualityState? _arPosQualityState;
  UnityViewController? _unityViewController;
  MapViewController? _mapViewController;
  ARModeManager? _arModeManager;
  final ValueNotifier<int> _current3DAmbience = ValueNotifier<int>(0);

  // The UnityView may be constantly created/disposed. On the disposed state,
  // any method call will probably be ignored (mostly in Android).
  // As a workaround we can keep a pending action that will be executed when
  // the UnityView#onCreated callback is invoked.
  Function? _navigationPendingAction;
  Function? _geofencesPendingAction;

  // Keep resumed state to avoid consecutive calls to "pause" on the UnityView
  // as it seems to be freezing the AR module on iOS.
  bool? _resumed;

  Timer? _timer;
  int refreshingTimer = 5;
  int timestampLastRefresh = 0;
  String navigationLastCoordinates = "";

  ARController._() {
    _arModeManager = ARModeManager(arModeChanged);
    SitumSdk().internalSetMethodCallARDelegate(_methodCallHandler);
  }

  factory ARController() {
    _instance ??= ARController._();
    return _instance!;
  }

  /// Let this ARController be up to date with the latest UnityViewController.
  void _onUnityViewController(UnityViewController? controller) {
    _unityViewController = controller;
  }

  /// Update this ARController with the ARPosQuality state so it can notify
  /// location updates and determine the alert visibility by itself.
  void _onARPosQualityState(_ARPosQualityState? state) {
    _arPosQualityState = state;
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

  /// Let this ARController know that the underlying Widget has been disposed.
  void _onARWidgetDispose() {
    // Reset state.
    _resumed = null;
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
    wakeup();
    _widgetState?.updateStatusArRequested();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.success);
    _mapViewController?.followUser();
    Future.delayed(_ARWidgetState.animationDuration, () {
      // Repeat the call to followUser after the animation, as it seems possible
      // to move the map during that time interval.
      _mapViewController?.followUser();
    });
    // Execute pending actions:
    if (_navigationPendingAction != null) {
      _navigationPendingAction?.call();
      _navigationPendingAction = null;
    }
    if (_geofencesPendingAction != null) {
      _geofencesPendingAction?.call();
      _geofencesPendingAction = null;
    }
    // Notify the client callback:
    _widgetState?.widget.onARVisibilityChanged?.call(ARVisibility.visible);
  }

  void onArGone() {
    _widgetState?.updateStatusArGone();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.finished);
    sleep();
    _widgetState?.widget.onARVisibilityChanged?.call(ARVisibility.gone);
  }

  void _cancelTimer() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
    }
  }

  void sleep() {
    // Pause only if not already paused or at the initial state.
    if (_resumed == null || _resumed == true) {
      _cancelTimer();
      _unityViewController?.pause();
      _resumed = false;
    }
  }

  void wakeup() {
    _timer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      _getOdometry();
    });
    startRefreshing(5);
    // Resume only if not already resumed or at the initial state.
    if (_resumed == null || _resumed == false) {
      _unityViewController?.resume();
      _resumed = true;
    }
  }

  bool _isReadyToReceiveMessages() {
    return _unityViewController != null && _resumed == true;
  }

  // === Set of methods to keep the AR module updated regarding position and navigation.
  Future<void> _methodCallHandler(InternalCall call) async {
    switch (call.type) {
      case InternalCallType.location:
        _onLocationChanged(call.get());
        break;
      case InternalCallType.navigationStart:
        _onNavigationStart(call.get());
        break;
      case InternalCallType.navigationDestinationReached:
        _onNavigationDestinationReached();
        break;
      case InternalCallType.navigationProgress:
        _onNavigationProgress(call.get());
        break;
      case InternalCallType.navigationOutOfRoute:
        _onNavigationOutOfRoute();
        break;
      case InternalCallType.navigationCancellation:
        _onNavigationCancelled();
        break;
      case InternalCallType.geofencesEnter:
        _onEnterGeofences(call.get());
        break;
      case InternalCallType.geofencesExit:
        _onExitGeofences(call.get());
        break;
      default:
        debugPrint("Unhandled call: ${call.type}");
        break;
    }
  }

  void refresh() {
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (currentTimestamp > timestampLastRefresh + 5000) {
      _unityViewController?.send("MessageManager", "ForceReposition", "null");
      timestampLastRefresh = currentTimestamp;
    }
  }

  void startRefreshing(int numRefresh) {
    ARModeDebugValues.refresh.value = true;
    refresh();
    refreshingTimer = numRefresh;
  }

  void stopRefreshing() {
    ARModeDebugValues.refresh.value = false;
    _unityViewController?.send("MessageManager", "SendRefressData", '1000000');
  }

  void _onLocationChanged(Location location) {
    var locationMap = location.toMap();
    locationMap['timestamp'] = 0;
    _unityViewController?.send(
        "MessageManager", "SendLocation", jsonEncode(locationMap));
    _updateArPosQualityState(location);
    _updateRefreshing();
  }

  void _updateRefreshing() {
    if (_arPosQualityState!.arLocations.isEmpty ||
        _arPosQualityState!.sdkLocationCoordinates.isEmpty) {
      return;
    }
    // check similarity
    var totalDisplacementSitum = _arPosQualityState?.computeTotalDisplacement(
        _arPosQualityState!.sdkLocationCoordinates, 20);
    var totalDisplacementAR = _arPosQualityState?.computeTotalDisplacement(
        _arPosQualityState!.arLocations, 20);

    var areOdoSimilar = _arPosQualityState?.estimateOdometriesMatch(
        _arPosQualityState!.arLocations,
        _arPosQualityState!.sdkLocationCoordinates);

    double arConf = _arPosQualityState!.estimateArConf();
    double situmConf = _arPosQualityState!.estimateSitumConf();
    double displacementConf =
        _arPosQualityState!.totalDisplacementConf(totalDisplacementSitum!);
    double displacementConfAR =
        _arPosQualityState!.totalDisplacementConf(totalDisplacementAR!);
    double odometriesDistanceConf =
        _arPosQualityState!.odometriesDifferenceConf(areOdoSimilar!.distance);
    // double odometriesAngleDifferenceConf = _arPosQualityState!
    //     .odometriesAngleDifferenceConf(areOdoSimilar.angularDistance);
    double qualityMetric = arConf *
        situmConf *
        displacementConf *
        displacementConfAR *
        odometriesDistanceConf; //TODO: Angle conf

    // check if has to refresh
    bool hasToRefresh = _arPosQualityState!
        .checkIfHasToRefreshAndUpdateThreshold(
            qualityMetric, arConf, situmConf);
    if (hasToRefresh) {
      int numRefresh = 1;
      startRefreshing(numRefresh);
    } else if (refreshingTimer > 0) {
      refresh();
      refreshingTimer--;
      if (refreshingTimer == 0) {
        stopRefreshing();
      }
    }

    // update debug info
    ARModeDebugValues.debugVariables.value = buildDebugMessage(
        ARModeDebugValues.refresh.value,
        areOdoSimilar,
        totalDisplacementSitum,
        totalDisplacementAR,
        _arPosQualityState!.arLocations.length,
        _arPosQualityState!.sdkLocationCoordinates.length,
        arConf,
        situmConf,
        ARModeDebugValues.dynamicRefreshThreshold.value,
        qualityMetric);
  }

  String buildDebugMessage(
      bool isRefreshing,
      areOdoSimilar,
      totalDisplacementSitum,
      totalDisplacementAR,
      arBufferSize,
      sdkBufferSize,
      arConf,
      situmConf,
      currentRefreshThreshold,
      qualityMetric) {
    String status = isRefreshing ? "REFRESHING" : "NOT REFRESHING";
    double angularDistanceDegrees = areOdoSimilar.angularDistance * 180 / pi;
    return "$status\n"
        "ar / Situm diff: ${areOdoSimilar.distance.toStringAsFixed(3)}  (${_arPosQualityState!.odometriesDifferenceConf(areOdoSimilar.distance).toStringAsFixed(3)})\n"
        "ar / situm angle diff: ${areOdoSimilar.angularDistance.toStringAsFixed(3)} , ${angularDistanceDegrees.toStringAsFixed(1)} , conf (${_arPosQualityState!.odometriesAngleDifferenceConf(areOdoSimilar.angularDistance).toStringAsFixed(3)})\n"
        "totalDisplacementSitum: ${totalDisplacementSitum.toStringAsFixed(3)}  (${_arPosQualityState!.totalDisplacementConf(totalDisplacementSitum!).toStringAsFixed(3)})\n"
        "totalDisplacementAR: ${totalDisplacementAR.toStringAsFixed(3)}\n"
        "ar buffer size: $arBufferSize\n"
        "sdk buffer size: $sdkBufferSize\n"
        "arCore Conf: $arConf\n"
        "situm Conf: $situmConf\n"
        "currentRefreshThreshold: ${currentRefreshThreshold.toStringAsFixed(3)}\n"
        "quality: ${qualityMetric.toStringAsFixed(3)}\n";
  }

  void _updateArPosQualityState(location) {
    _arPosQualityState?.updateLocation(location);
  }

  void _onNavigationCancelled() {
    if (_isReadyToReceiveMessages()) {
      _unityViewController?.send("MessageManager", "CancelRoute", "null");
      _arModeManager?.updateWithNavigationStatus(NavigationStatus.finished);
    } else {
      _navigationPendingAction = () => _onNavigationCancelled();
    }
  }

  void _onNavigationDestinationReached() {
    if (_isReadyToReceiveMessages()) {
      _unityViewController?.send("MessageManager", "SendRouteEnd", "null");
      _unityViewController?.send(
          "MessageManager", "SendDisableArrowGuide", "null");
      _arModeManager?.updateWithNavigationStatus(NavigationStatus.finished);
      onArGone();
    } else {
      _navigationPendingAction = () => _onNavigationDestinationReached();
    }
  }

  void _onNavigationOutOfRoute() {
    if (_isReadyToReceiveMessages()) {
      _unityViewController?.send("MessageManager", "SendRouteUserOut", "null");
    } else {
      _navigationPendingAction = () => _onNavigationOutOfRoute();
    }
  }

  void updateArArrowGuide(RouteProgress progress) {
    dynamic progressContent = jsonDecode(jsonEncode(progress.rawContent));
    String nextCoordinates = findNextCoordinates(progressContent);
    if (nextCoordinates == "floorChange") {
      _unityViewController?.send(
          "MessageManager", "SendDisableArrowGuide", "null");
      navigationLastCoordinates = nextCoordinates;

      ARModeDebugValues.nextIndicationUp.value =
          getFloorChangeDirection(progressContent);
      ARModeDebugValues.nextIndicationChangeFloor.value = true;
    } else if (navigationLastCoordinates != nextCoordinates &&
        nextCoordinates != "") {
      if (navigationLastCoordinates == "floorChange") {
        // After floor change , enable arrow
        _unityViewController?.send(
            "MessageManager", "SendEnableArrowGuide", "null");
        ARModeDebugValues.nextIndicationChangeFloor.value = false;
      }

      navigationLastCoordinates = nextCoordinates;
      _unityViewController?.send(
          "MessageManager", "SendArrowTarget", nextCoordinates);
      _unityViewController?.send(
          "MessageManager", "SendEnableArrowGuide", "null");
    }
  }

  void _onNavigationProgress(RouteProgress progress) {
    updateArArrowGuide(progress);
    _unityViewController?.send(
        "MessageManager", "SendRouteProgress", jsonEncode(progress.rawContent));
  }

  void _onNavigationStart(SitumRoute route) {
    if (_isReadyToReceiveMessages()) {
      debugPrint("Situm> AR> Navigation> _onNavigationStart");
      _unityViewController?.send(
          "MessageManager", "SendHideRouteElements", "null");
      _unityViewController?.send(
          "MessageManager", "SendRoute", jsonEncode(route.rawContent));
      startRefreshing(5);
      _arModeManager?.updateWithNavigationStatus(NavigationStatus.started);
    } else {
      _navigationPendingAction = () => _onNavigationStart(route);
    }
  }

  void _onEnterGeofences(List<Geofence> geofences) {
    ARMetadata? arMetadata = ARMetadata._fromGeofences(geofences);
    if (arMetadata != null) {
      if (_isReadyToReceiveMessages()) {
        _selectAmbience(arMetadata.ambienceCode);
      } else {
        _geofencesPendingAction = () => _onEnterGeofences(geofences);
      }
      // Keep the state updated anyway so the AR module don't miss ambience
      // changes when it is paused.
      _current3DAmbience.value = arMetadata.ambienceCode;
    }
  }

  void _onExitGeofences(List<Geofence> geofences) {
    ARMetadata? arMetadata = ARMetadata._fromGeofences(geofences);
    if (arMetadata != null &&
        (_current3DAmbience.value == arMetadata.ambienceCode ||
            _current3DAmbience.value == 0)) {
      if (_isReadyToReceiveMessages()) {
        _selectAmbience(0);
      } else {
        _geofencesPendingAction = () => _onExitGeofences(geofences);
      }
      // Keep the state updated anyway so the AR module don't miss ambience
      // changes when it is paused.
      _current3DAmbience.value = 0;
    }
  }

  void setSelectedPoi(Poi poi) {
    _unityViewController?.send(
        "MessageManager", "SendLastSelectedPOI", jsonEncode(poi.toMap()));
  }

  //Callback called when the arMode has changed
  void arModeChanged(ARMode arMode) {
    ARModeDebugValues.arMode = arMode;
    updateUnityModeParams(arMode);
  }

  void updateUnityModeParams(ARMode arMode) {
    ARModeUnityParams unityParams =
        ARModeDebugValues.getUnityParamsForMode(arMode);
    //_setARModeParams(unityParams);    //TODO: Check
  }

  void _setARModeParams(ARModeUnityParams arModeUnityParams) {
    debugPrint("UPDATE AR PARAMS: $arModeUnityParams");
    _lastSetARModeUnityParams = arModeUnityParams;
    _unityViewController?.send("MessageManager", "SendRefressData",
        arModeUnityParams.refreshData.toString());
    _unityViewController?.send("MessageManager", "SendDistanceLimitData",
        arModeUnityParams.distanceLimit.toString());
    _unityViewController?.send("MessageManager", "SendAngleLimitData",
        arModeUnityParams.angleLimit.toString());
    _unityViewController?.send("MessageManager", "SendAccurancyLimitData",
        arModeUnityParams.accuracyLimit.toString());
    _unityViewController?.send("MessageManager", "SendCameraLimit",
        arModeUnityParams.cameraLimit.toInt().toString());
  }

  /// Change the AR ambience (private by now).
  void _selectAmbience(int ambienceCode) {
    _unityViewController?.send(
        "MessageManager", "SendOnAmbienceZoneEnter", "$ambienceCode");
    _widgetState?._updateStatusAmbienceSelected(ambienceCode);
    debugPrint("Situm> AR> Ambiences> Selected $ambienceCode");
  }

  void _setEnjoyMode(bool enjoySelected) {
    if (enjoySelected) {
      _unityViewController?.send(
          "MessageManager", "SendHideRouteElements", "null");
      _arModeManager?.setARMode(ARMode.enjoy);
    } else {
      _unityViewController?.send(
          "MessageManager", "SendShowRouteElements", "null");
      _arModeManager?.switchToPreviousMode();
    }
  }

  void _getOdometry() {
    _unityViewController?.send("MessageManager", "GetOdometryData", "null");
  }
}
