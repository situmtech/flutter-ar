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
  bool isArVisible = false;
  bool isMapCollapsed = false;
  ARDebugUI debugUI = ARDebugUI();
  ScrollController scrollController = ScrollController();
  static const int animationMillis = 200;
  static const Duration animationDuration =
      Duration(milliseconds: animationMillis);
  static const Duration animationDurationWithDelay =
      Duration(milliseconds: animationMillis + 100);

  late String sessionId;

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
    sessionId = DateFormat('yyyyMMddHHmmss').format(DateTime.now());
    ARController()._onARWidgetState(this);
  }

  @override
  Widget build(BuildContext context) {
    // Create the AR widget:
    var unityView = UnityView(
      onCreated: (controller) => onUnityViewCreated(context, controller),
      onReattached: onUnityViewReattached,
      onMessage: onUnityViewMessage,
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
        Stack(
          children: [
            // Add the AR Widget at the bottom of the stack. It will start
            // loading even when it is not visible.
            unityView,
            // TODO: fix this:
            //...debugUI.createAlertVisibilityParamsDebugWidgets(),
            //...debugUI.createUnityParamsDebugWidgets(),
            //...debugUI.createDynamicUnityParamsWidgets(),
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
    arController.updateUnityModeParams(DEFAULT_AR_MODE);
    // Resume Unity Player if there is a MapView. Otherwise the AR Widget will
    // be hidden.
    if (widget.mapView == null) {
      arController.wakeup();
    } else {
      arController.sleep();
    }
    widget.onCreated.call();
  }

  void onUnityViewReattached(UnityViewController controller) {
    debugPrint("Situm> AR> REATTACHED!");
  }

  void _saveMessageToFile(String? message, int timestamp) async {
    try {
      if (message != null) {
        if (Platform.isAndroid || Platform.isIOS) {
          //Directory? directory = await getExternalStorageDirectory();
          Directory? directory = await getApplicationDocumentsDirectory();
          File file = File('${directory.path}/$sessionId.csv');

          if (!await file.exists()) {
            await file.create(recursive: true);
            await file.writeAsString(
                'timestamp,position.x,position.y,position.z,rotation.x,rotation.y,rotation.z\n',
                mode: FileMode.append);
          } else {
            Map<String, dynamic> messageMap = json.decode(message);

            String csvLine = '$timestamp';
            messageMap.forEach((key, value) {
              if (value is Map) {
                value.forEach((k, v) {
                  csvLine += ',$v';
                });
              } else {
                csvLine += ',$value';
              }
            });
            await file.writeAsString('$csvLine\n', mode: FileMode.append);
            debugPrint("Writing message : $message, to path ${file.path}");
          }
        } else {
          debugPrint('Error: Only for Android or iOS.');
        }
      }
    } catch (e) {
      debugPrint('Error saving message: $e');
    }
  }

  void onUnityViewMessage(UnityViewController? controller, String? message) {
    debugPrint("Situm> AR> MESSAGE! $message");

    if (message == "BackButtonTouched") {
      arController.onArGone();
    } else {
      int timestamp = DateTime.now().millisecondsSinceEpoch;
      _saveMessageToFile(message, timestamp);
    }
  }

  @override
  void dispose() {
    super.dispose();
    arController._onARPosQualityState(null);
    arController._onUnityViewController(null);
    arController._onARWidgetState(null);
    arController._onARWidgetDispose();
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
        arController.onArGone();
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
    Future.delayed(const Duration(seconds: 1), centerAction);
  }

  void updateStatusArGone() {
    setState(() {
      isArVisible = false;
    });
  }

  void _updateStatusAmbienceSelected(int ambienceCode) {
    if (widget.enable3DAmbiences && isArVisible) {
      var message = ambienceCode != 0 // TODO: apply here a better design!
          ? "Enjoy ${_AmbienceSelectorState._ambiences3DNames[ambienceCode]}!"
          : "Exiting 3D ambience.";
      _showToast(context, message);
    }
  }

  _onARPosQuality(_ARPosQualityState state) {
    arController._onARPosQualityState(state);
  }
}
