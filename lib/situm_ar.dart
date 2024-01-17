part of situm_flutter_ar;

class ARWidget extends StatefulWidget {
  final String buildingIdentifier;
  final Function() onCreated;
  final Function() onPopulated;
  final Function onDisposed;
  final MapView? mapView;
  final double arHeightRatio;

  /// Widget for augmented reality compatible with Situm MapView.
  /// - mapView: Optional MapView, to be integrated with the augmented reality module.
  /// - arHeightRatio: Screen ratio (from 0 to 1) that the augmented reality view will occupy.
  const ARWidget({
    super.key,
    required this.buildingIdentifier,
    required this.onCreated,
    required this.onPopulated,
    required this.onDisposed,
    this.mapView,
    this.arHeightRatio = 2 / 3,
  });

  @override
  State createState() => _ARWidgetState();
}

class _ARWidgetState extends State<ARWidget> {
  UnityViewController? unityViewController;
  bool mapViewLoaded = false;
  bool isArVisible = false;
  bool isArAvailable = false;
  ARDebugUI debugUI = ARDebugUI();

  @override
  void initState() {
    super.initState();
    ARController()._onARWidgetState(this);
  }

  @override
  Widget build(BuildContext context) {
    // Create the AR widget:
    var unityView = Platform.isIOS
        ? UnityView(
            onCreated: (controller) => onUnityViewCreated(context, controller),
            onReattached: onUnityViewReattached,
            onMessage: onUnityViewMessage,
          )
        // TODO: temp, remove when we are happy with Android.
        : _ARWIPScreen(
            onBackButtonPressed: () =>
                {onUnityViewMessage(null, "BackButtonTouched")},
            onWidgetCreated: () => {onUnityViewCreated(context, null)},
          );

    // If there is not a MapView, return it immediately:
    if (widget.mapView == null) {
      return unityView;
    }
    // Else integrate AR and MapView:
    assert(widget.arHeightRatio >= 0 && widget.arHeightRatio <= 1,
        'arHeightRatio must be a value between 0 and 1');
    var mapView = widget.mapView!;
    var arHeight = MediaQuery.of(context).size.height * widget.arHeightRatio;
    var mapHeightARMode =
        MediaQuery.of(context).size.height * (1 - widget.arHeightRatio);
    var mapHeightFullMode = MediaQuery.of(context).size.height;

    // Use this stack to show a debug FAB button:
    // return Stack(
    //   children: [
    return Stack(
      children: [
        // AR view:
        Visibility(
          visible: mapViewLoaded,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: arHeight,
              child: Stack(
                children: [
                  unityView,
                  // TODO: fix this:
                  //...debugUI.createAlertVisibilityParamsDebugWidgets(),
                  //...debugUI.createUnityParamsDebugWidgets(),
                  _ARPosQuality(onCreate: onARPosQuality),
                ],
              ),
            ),
          ),
        ),
        // MapView:
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedSize(
            duration: const Duration(milliseconds: 50),
            child: SizedBox(
              height: isArVisible ? mapHeightARMode : mapHeightFullMode,
              child: mapView,
            ),
          ),
        ),
      ],
    );
    //     Visibility(
    //       visible: true,
    //       child: Align(
    //         alignment: Alignment.bottomRight,
    //         child: FloatingActionButton(
    //           onPressed: () {
    //             setState(() {
    //               isArVisible = !isArVisible;
    //               var arController = ARController();
    //               if (isArVisible) {
    //                 arController.onArRequested();
    //               } else {
    //                 arController.onArGone();
    //               }
    //             });
    //           },
    //           child: Icon(
    //               isArVisible ? Icons.map_outlined : Icons.camera_outlined),
    //         ),
    //       ),
    //     ),
    //   ],
    // );
  }

  void onUnityViewCreated(
      BuildContext context, UnityViewController? controller) {
    debugPrint("Situm> AR> onUnityViewCreated");
    unityViewController = controller;
    var sdk = SitumSdk();
    sdk.fetchBuildingInfo(widget.buildingIdentifier).then((buildingInfo) {
      var buildingInfoMap = buildingInfo.toMap();
      controller?.send(
          "MessageManager", "SendBuildingInfo", jsonEncode(buildingInfoMap));
      debugPrint("Situm> AR> BuildingInfo has been sent.");
      var poisMap = buildingInfoMap["indoorPOIs"];
      controller?.send("MessageManager", "SendPOIs", jsonEncode(poisMap));
      debugPrint("Situm> AR> indoorPOIs array has been sent.");
      widget.onPopulated.call();
    });
    var arController = ARController(); // Initialize/update (singleton).
    arController._onUnityViewController(controller);
    debugUI.controller = controller;
    arController.updateUnityModeParams(ARMode.relaxed);
    // Resume Unity Player if there is a MapView. Otherwise the AR Widget will
    // be hidden.
    if (widget.mapView == null) {
      arController.wakeup();
    } else {
      arController.sleep();
    }
    setState(() {
      isArAvailable = true;
    });
    widget.onCreated.call();
  }

  void onUnityViewReattached(UnityViewController controller) {
    debugPrint("Situm> AR> REATTACHED!");
  }

  void onUnityViewMessage(UnityViewController? controller, String? message) {
    debugPrint("Situm> AR> MESSAGE! $message");
    if (message == "BackButtonTouched") {
      ARController arController = ARController();
      arController.onArGone();
    }
  }

  @override
  void dispose() {
    super.dispose();
    debugPrint("Situm> AR> dispose()");
    unityViewController?.pause();
    var arController = ARController();
    arController._onUnityViewController(null);
    arController._onARWidgetState(null);
  }

  void updateStatusArRequested() {
    setState(() {
      isArVisible = true;
    });
  }

  void updateStatusArGone() {
    setState(() {
      isArVisible = false;
    });
  }

  onARPosQuality(_ARPosQualityState state) {
    var arController = ARController();
    arController._onARPosQualityState(state);
  }

  _onMapViewLoaded() {
    setState(() {
      mapViewLoaded = true;
    });
  }
}

class ARController {
  static ARController? _instance;

  _ARWidgetState? _widgetState;
  _ARPosQualityState? _arPosQualityState;
  UnityViewController? _unityViewController;
  MapViewController? _mapViewController;
  ARModeManager? _arModeManager;

  // The UnityView may be constantly created/disposed. On the disposed state,
  // any method call will probably be ignored (mostly in Android).
  // As a workaround we can keep a pending action that will be executed when
  // the UnityView#onCreated callback is invoked.
  Function? _navigationPendingAction;

  ARController._() {
    _arModeManager = ARModeManager(arModeChanged);
  }

  factory ARController() {
    _instance ??= ARController._();
    return _instance!;
  }

  /// Let this ARController be up to date with the latest UnityViewController.
  void _onUnityViewController(UnityViewController? controller) {
    _unityViewController = controller;
    if (_unityViewController != null && _navigationPendingAction != null) {
      _navigationPendingAction?.call();
      _navigationPendingAction = null;
    }
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

  // === Internal MapViewer messages:

  /// Notifies the AR module that the MapView has been loaded, ensuring seamless
  /// integration between both.
  void onMapViewLoad(MapViewController controller) {
    _mapViewController = controller;
    controller.internalARMessageDelegate(_onMapViewMessage);
    _widgetState?._onMapViewLoaded();
    debugPrint("Situm> AR> onMapViewLoad");
  }

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
    _widgetState?.updateStatusArRequested();
    wakeup();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.success);
  }

  void onArGone() {
    _widgetState?.updateStatusArGone();
    sleep();
    _mapViewController?.updateAugmentedRealityStatus(ARStatus.finished);
  }

  void sleep() {
    _unityViewController?.pause();
  }

  void wakeup() {
    _unityViewController?.resume();
  }

  // === Set of methods to keep the AR module updated regarding position and navigation.

  void setLocation(Location location) {
    var locationMap = location.toMap();
    locationMap['timestamp'] = 0;
    _unityViewController?.send(
        "MessageManager", "SendLocation", jsonEncode(locationMap));
    _arPosQualityState?.updateLocation(location);
  }

  void setNavigationCancelled() {
    if (_unityViewController != null) {
      _unityViewController?.send("MessageManager", "CancelRoute", "null");
      _arModeManager?.updateARMode(NavigationStatus.finished);
    } else {
      _navigationPendingAction = () => setNavigationCancelled();
    }
  }

  void setNavigationDestinationReached() {
    if (_unityViewController != null) {
      _unityViewController?.send("MessageManager", "SendRouteEnd", "null");
      _arModeManager?.updateARMode(NavigationStatus.finished);
    } else {
      _navigationPendingAction = () => setNavigationDestinationReached();
    }
  }

  void setNavigationOutOfRoute() {
    if (_unityViewController != null) {
      _unityViewController?.send("MessageManager", "SendRouteUserOut", "null");
    } else {
      _navigationPendingAction = () => setNavigationOutOfRoute();
    }
  }

  void setNavigationProgress(RouteProgress progress) {
    _unityViewController?.send(
        "MessageManager", "SendRouteProgress", jsonEncode(progress.rawContent));
  }

  void setNavigationStart(SitumRoute route) {
    if (_unityViewController != null) {
      _unityViewController?.send(
          "MessageManager", "SendRoute", jsonEncode(route.rawContent));
      _arModeManager?.updateARMode(NavigationStatus.started);
    } else {
      _navigationPendingAction = () => setNavigationStart(route);
    }
  }

  void setSelectedPoi(Poi poi) {
    _unityViewController?.send(
        "MessageManager", "SendLastSelectedPOI", jsonEncode(poi.toMap()));
  }

  //Callback thas is called when the arMode has changed
  void arModeChanged(ARMode arMode) {
    ARModeDebugValues.arMode = arMode;
    updateUnityModeParams(arMode);
  }

  void updateUnityModeParams(ARMode arMode) {
    ARModeUnityParams unityParams =
        ARModeDebugValues.getUnityParamsForMode(arMode);
    _setARModeParams(unityParams);
  }

  void _setARModeParams(ARModeUnityParams arModeUnityParams) {
    _unityViewController?.send("MessageManager", "SendRefressData",
        arModeUnityParams.refreshData.toString());
    _unityViewController?.send("MessageManager", "SendDistanceLimitData",
        arModeUnityParams.distanceLimit.toString());
    _unityViewController?.send("MessageManager", "SendAngleLimitData",
        arModeUnityParams.angleLimit.toString());
    _unityViewController?.send("MessageManager", "SendAccurancyLimitData",
        arModeUnityParams.accuracyLimit.toString());
    _unityViewController?.send("MessageManager", "SendCameraLimit",
        arModeUnityParams.cameraLimit.toString());
  }
}
