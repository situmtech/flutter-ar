part of 'ar.dart';

class ARWidget extends StatefulWidget {
  final String buildingIdentifier;
  final String apiDomain;
  final Function() onCreated;
  final Function() onPopulated;
  final Function onDisposed;
  final Function(ARVisibility)? onARVisibilityChanged;
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
    this.onARVisibilityChanged,
    this.mapView,
    this.arHeightRatio = 2 / 3,
    this.debugMode = false,
    this.apiDomain = "https://dashboard.situm.com",
    // TODO: restore.
    this.enable3DAmbiences = false,
    // TODO: restore.
    this.occlusionAndroid = true,
    // TODO: restore.
    this.occlusionIOS = true,
  });

  @override
  State createState() => _ARWidgetState();
}

class _ARWidgetState extends State<ARWidget> with WidgetsBindingObserver {
  late String apiDomain;
  ARController arController = ARController();
  bool isArVisible = false;
  bool isMapCollapsed = false;
  bool loadingArMessage = false;
  Timer? loadingArMessageTimer;
  ScrollController scrollController = ScrollController();
  static const int animationMillis = 200;
  static const Duration animationDuration =
      Duration(milliseconds: animationMillis);
  static const Duration animationDurationWithDelay =
      Duration(milliseconds: animationMillis + 100);

  @override
  void initState() {
    super.initState();
    if (widget.mapView != null &&
        widget.mapView?.configuration.displayWithHybridComposition != false) {
      // TODO: this is not necessary when using Impeller rendering engine.
      throw Exception(
          "You must set displayWithHybridComposition to false in the MapView configuration.");
    }
    WidgetsBinding.instance.addObserver(this);
    var validations = _Validations();
    apiDomain = validations.validateApiDomain(widget.apiDomain);
    if (widget.enable3DAmbiences) {
      var situmSdk = SitumSdk();
      situmSdk.init();
      situmSdk.internalEnableGeofenceListening();
    }

    ARController()._onARWidgetState(this);
  }

  void _onARViewCreated(BuildContext context, ARController? controller) async {
    // Do nothing. TODO: delete?
  }

  @override
  Widget build(BuildContext context) {
    var arView = ARView(
      onCreated: (controller) => _onARViewCreated(context, controller),
    );

    if (widget.mapView == null) {
      return arView;
    }

    // Else integrate AR and MapView:
    assert(widget.arHeightRatio >= 0 && widget.arHeightRatio <= 1,
        'arHeightRatio must be a value between 0 and 1');
    return Stack(
      children: [
        // ============== AR view ==============================================
        Stack(
          children: [
            // Add the AR Widget at the bottom of the stack. It will start
            // loading even when it is not visible.
            arView,
            ArScreenBackButton(onPressed: () {
              arController.onArGone();
            }),
            if (loadingArMessage) const ARLoadingWidget()
          ],
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
                    child: Container(
                      // This opaque Container prevents the AR widget from being
                      // visible while the map is not loaded.
                      color: Colors.grey[200],
                      child: SizedBox(
                        // Set the map height equals to the container.
                        height: constraints.maxHeight,
                        child: widget.mapView!,
                      ),
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
        if (widget.debugMode)
          _createDebugModeSwitchButton(() {
            setState(() {
              isArVisible = !isArVisible;
            });
            isArVisible
                ? arController.onArRequested()
                : arController.onArGone();
          }),
      ],
    );
  }

  @override
  void dispose() {
    super.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
      case AppLifecycleState.resumed:
        debugPrint("Situm> AR> LIFECYCLE> App is $state");
        break;
      case AppLifecycleState.inactive:
        debugPrint("Situm> AR> LIFECYCLE> INACTIVE");
        // This behavior was disabled because it was too aggressive. For
        // example, simply sliding down the Android notification panel was
        // enough to hide the AR. It was moved to the native side:
        // Android -> onStop() lifecycle method is perfect to detect when the
        // app goes to background or the phone is locked, but is not called
        // if the app is only partially covered.
        // arController.onArGone();
        break;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint("Situm> AR> LIFECYCLE> didChangeDependencies");
  }

  void updateStatusArRequested() {
    setState(() {
      isArVisible = true;
      isMapCollapsed = false;
    });
    centerAction() {
      // "Center" the MapView into the ScrollView:
      if (isArVisible) {
        scrollController
            .jumpTo(scrollController.position.maxScrollExtent * 2 / 5);
      }
    }

    // Use animationDurationWithDelay to move the scroll that contains the MapView
    // This ensures it has been completely resized (after animationDuration).
    Future.delayed(animationDurationWithDelay, centerAction);
    // Watchdog:
    Future.delayed(const Duration(milliseconds: 1500), centerAction);

    // Create a "AR Loading" message that disappears after 10s.:
    setState(() {
      loadingArMessage = true;
    });
    loadingArMessageTimer = Timer(const Duration(seconds: 10), () {
      setState(() {
        loadingArMessageTimer = null;
        loadingArMessage = false;
      });
    });
  }

  void updateStatusArGone() {
    loadingArMessageTimer?.cancel();
    setState(() {
      isArVisible = false;
      loadingArMessage = false;
    });
  }
}
