part of 'ar.dart';




class SitumAr {
  static const MethodChannel _channel = MethodChannel('situm_ar');

  static Future<void> startARView() async {
    await _channel.invokeMethod('startARView');
  }

  static Future<void> updatePOIs(Map<String, dynamic> poisMap) async {
    await _channel.invokeMethod('updatePOIs', poisMap);
  }
}

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
    this.enable3DAmbiences = false,
    this.occlusionAndroid = true,
    this.occlusionIOS = true,
  });

  @override
  State createState() => _ARWidgetState();
}

class _ARWidgetState extends State<ARWidget> with WidgetsBindingObserver {
  late String apiDomain;
  ARController arController = ARController();
  ARView arViewWidget = ARView();
  bool isArVisible = false;
  bool isMapCollapsed = false;
  bool loadingArMessage = false;
  Timer? loadingArMessageTimer;
  ARDebugUI debugUI = ARDebugUI();
  ScrollController scrollController = ScrollController();
  static const int animationMillis = 200;
  static const Duration animationDuration =
      Duration(milliseconds: animationMillis);
  static const Duration animationDurationWithDelay =
      Duration(milliseconds: animationMillis + 100);

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    // Crea la vista de AR
    var arView = ARView(
      onCreated: (controller) => onARViewCreated(context, controller),
      onReattached: onARViewReattached,
      onMessage: onARViewMessage,
    );

    // Verifica que el arHeightRatio esté dentro del rango válido
    assert(widget.arHeightRatio >= 0 && widget.arHeightRatio <= 1,
        'arHeightRatio must be a value between 0 and 1');

    return Stack(
      children: [
        // ============== MapView (fondo) ======================================
        if (widget.mapView != null)
          Positioned.fill(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                double mapHeight = constraints.maxHeight * (1 - widget.arHeightRatio);
                return SizedBox(
                  height: mapHeight,
                  child: widget.mapView!,
                );
              },
            ),
          ),

        // ============== AR view (frente) =====================================
        Positioned.fill(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              double arHeight = constraints.maxHeight * widget.arHeightRatio;
              return Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: arHeight,
                  child: arView,
                ),
              );
            },
          ),
        ),

        // ============== Expand/collapse AR ===================================
        if (widget.mapView != null)
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

        // ============== Debug Mode (opcional) ================================
        if (widget.debugMode)
          _createDebugModeSwitchButton(() {
            isArVisible
                ? arController.onArGone()
                : arController.onArRequested();
          }),
      ],
    );
  }

  void onARViewMessage(ARViewController? controller, String? message) {
    debugPrint("Situm> AR> MESSAGE!!!!!!!!!!!!!!! $message");
  }

  void onARViewCreated(BuildContext context, ARViewController? controller) {
    debugPrint("Situm> AR> onARViewCreated!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
  }

  void onARViewReattached(ARViewController controller) {
    debugPrint("Situm> AR> REATTACHED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
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
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        debugPrint("Situm> AR> LIFECYCLE> App is $state");
        break;
      case AppLifecycleState.inactive:
        debugPrint("Situm> AR> LIFECYCLE> INACTIVE --> PAUSE AR");
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

  void _updateStatusAmbienceSelected(int ambienceCode) {
    if (widget.enable3DAmbiences && isArVisible) {
      var message = "Please be conscious of other people while navigating";
      _showToast(context, message, const Duration(seconds: 3));
    }
  }

  _onARPosQuality(_ARPosQualityState state) {}
}
