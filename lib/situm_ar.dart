part of 'ar.dart';

class ARWidget extends StatefulWidget {
  final String buildingIdentifier;
  final String apiDomain;
  final Function() onCreated;
  final Function() onPopulated;
  final Function onDisposed;
  final MapView? mapView;
  final double arHeightRatio;
  final bool debugMode;
  final bool enable3DAmbiences;
  final bool occlusionAndroid;
  final bool occlusionIOS;

  /// Widget for augmented reality compatible with Situm MapView.
  /// - buildingIdentifier: The building that will be loaded.
  /// - mapView: Optional MapView, to be integrated with the augmented reality module.
  /// - arHeightRatio: Screen ratio (from 0 to 1) that the augmented reality view will occupy. Default is 2/3.
  /// - apiDomain: A String parameter that allows you to choose the API you will be retrieving
  /// our cartography from. Default is https://dashboard.situm.com.
  /// - enable3DAmbiences: Recreate ambiences in the augmented reality view with animations and 3D objects.
  /// The activation of each environment is based on the entry/exit on [Geofence]s,
  /// which must be configured in the dashboard through the "ar_metadata" custom field. Default value is false.
  /// Example:
  /// ```dart
  /// ar_metadata: {"ambience": "oasis"}
  /// ```.
  /// - occlusionAndroid, occlusionIOS: Enable or disable 3D model occlusion. Default value is true.
  const ARWidget({
    super.key,
    required this.buildingIdentifier,
    required this.onCreated,
    required this.onPopulated,
    required this.onDisposed,
    this.mapView,
    this.arHeightRatio = 2 / 3,
    this.debugMode = false,
    this.apiDomain = "https://dashboard.situm.com",
    this.enable3DAmbiences = false,
    this.occlusionAndroid = true,
    this.occlusionIOS = true,
  });

  @override
  State createState() => _ARWidgetState();
}

class _ARWidgetState extends State<ARWidget> {
  ARController arController = ARController();
  UnityViewController? unityViewController;
  bool mapViewLoaded = false;
  bool isArVisible = false;
  bool isArAvailable = false;
  bool isMapCollapsed = false;
  ARDebugUI debugUI = ARDebugUI();
  ScrollController scrollController = ScrollController();
  static const Duration animationDuration = Duration(milliseconds: 200);
  late String apiDomain;

  @override
  void initState() {
    super.initState();
    var validations = _Validations();
    apiDomain = validations.validateApiDomain(widget.apiDomain);
    if (widget.enable3DAmbiences) {
      var situmSdk = SitumSdk();
      situmSdk.init();
      situmSdk.internalEnableGeofenceListening();
    }
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
    return Stack(
      children: [
        // ============== AR view ==============================================
        Visibility(
          visible: mapViewLoaded,
          child: Stack(
            children: [
              unityView,
              // TODO: fix this:
              //...debugUI.createAlertVisibilityParamsDebugWidgets(),
              //...debugUI.createUnityParamsDebugWidgets(),
              _ARPosQuality(onCreate: _onARPosQuality),
              // TODO: fix at Unity (message not being received):
              _createTempBackButton(() {
                arController.onArGone();
              }),
              widget.enable3DAmbiences
                  ? _AmbienceSelector(
                      debugMode: widget.debugMode,
                    )
                  : const SizedBox(),
            ],
          ),
        ),
        // ============== MapView ==============================================
        Align(
          alignment: Alignment.bottomCenter,
          child: LayoutBuilder(
            // Let us know about the container's height.
            builder: (BuildContext context, BoxConstraints constraints) {
              double visibleMapHeight = isArVisible
                  // If the AR is visible, make the MapView height depend on the
                  // state collapsed/expanded:
                  ? (isMapCollapsed
                      ? 0
                      : constraints.maxHeight * (1 - widget.arHeightRatio))
                  // If the AR is not visible, make the MapView full height:
                  : constraints.maxHeight;
              return AbsorbPointer(
                absorbing: isArVisible,
                child: AnimatedContainer(
                  // NOTE: visibleMapHeight must be a property of AnimatedContainer
                  // as it will not animate changes on a child.
                  duration: animationDuration,
                  curve: Curves.decelerate,
                  height: visibleMapHeight,
                  child: SingleChildScrollView(
                    // Add ScrollView to center the map: TODO fix MapView resizing on iOS.
                    controller: scrollController,
                    physics: const NeverScrollableScrollPhysics(),
                    child: SizedBox(
                      // Set the map height equals to the container.
                      height: constraints.maxHeight,
                      child: widget.mapView!,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // ============== Expand/collapse AR ===================================
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedOpacity(
            opacity: isArVisible ? 1 : 0,
            duration: animationDuration,
            child: SizedBox(
              height: 32,
              width: 32,
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    isMapCollapsed = !isMapCollapsed;
                  });
                },
                backgroundColor: Colors.white,
                foregroundColor: Colors.black54,
                child: isMapCollapsed
                    ? const Icon(Icons.add)
                    : const Icon(Icons.remove),
              ),
            ),
          ),
        ),
        widget.debugMode
            ? _createDebugModeSwitchButton(() {
                isArVisible
                    ? arController.onArGone()
                    : arController.onArRequested();
              })
            : const SizedBox(),
      ],
    );
  }

  void onUnityViewCreated(
      BuildContext context, UnityViewController? controller) {
    debugPrint("Situm> AR> onUnityViewCreated");
    unityViewController = controller;
    if ((Platform.isAndroid && widget.occlusionAndroid) ||
        (Platform.isIOS && widget.occlusionIOS)) {
      controller?.send("MessageManager", "SendActivateOcclusion ", "null");
    } else {
      controller?.send("MessageManager", "SendDeactivateOcclusion ", "null");
    }
    var sdk = SitumSdk();
    sdk.fetchBuildingInfo(widget.buildingIdentifier).then((buildingInfo) {
      controller?.send("MessageManager", "SendContentUrl", apiDomain);
      var buildingInfoMap = buildingInfo.toMap();
      controller?.send(
          "MessageManager", "SendBuildingInfo", jsonEncode(buildingInfoMap));
      debugPrint("Situm> AR> BuildingInfo has been sent.");
      var poisMap = buildingInfoMap["indoorPOIs"];
      controller?.send("MessageManager", "SendPOIs", jsonEncode(poisMap));
      debugPrint(
          "Situm> AR> indoorPOIs array has been sent. API DOMAIN IS $apiDomain");
      widget.onPopulated.call();
    });
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
      arController.onArGone();
    }
  }

  @override
  void dispose() {
    super.dispose();
    debugPrint("Situm> AR> dispose()");
    unityViewController?.pause();
    arController._onUnityViewController(null);
    arController._onARWidgetState(null);
  }

  void updateStatusArRequested() {
    setState(() {
      isArVisible = true;
      isMapCollapsed = false;
    });
    Future.delayed(animationDuration, () {
      // "Center" the MapView into the ScrollView:
      scrollController
          .jumpTo(scrollController.position.maxScrollExtent * 2 / 5);
    });
  }

  void updateStatusArGone() {
    setState(() {
      isArVisible = false;
    });
  }

  _onARPosQuality(_ARPosQualityState state) {
    arController._onARPosQualityState(state);
  }

  _onMapViewLoaded() {
    setState(() {
      mapViewLoaded = true;
    });
  }
}
