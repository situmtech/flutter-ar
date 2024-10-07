part of 'ar.dart';

class SitumAr {
  static const MethodChannel _channel = MethodChannel('situm_ar');

  static Future<void> startARView() async {
    await _channel.invokeMethod('startARView');
  }

  static Future<void> updatePOIs(List<Map<String, dynamic>> poisList, double width) async {
    // Crea un mapa con la lista de POIs y el ancho
    final Map<String, dynamic> updatedPoisMap = {
      'pois': poisList, // Aquí 'poisMap' debe ser una lista de mapas
      'width': width,
    };

    // Llama al método de actualización de POIs en el canal
    await _channel.invokeMethod('updatePOIs', updatedPoisMap);
  }

  // Método para enviar una notificación a ContentView.swift
  static Future<void> sendNotificationToContentView() async {
    await _channel.invokeMethod('sendNotification');
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
    this.arHeightRatio = 1 / 2,
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
        if (isArVisible) 
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
                height: 52,
                width: 52,
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

        // ============== Botón para enviar notificación =======================
        Positioned(
          bottom: 50,
          right: 20,
          child: FloatingActionButton(
            onPressed: () {
              // Llamar al método para enviar la notificación             
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Updating AR View"),
                  duration: Duration(seconds: 2), // El Snackbar desaparecerá después de 2 segundos
                ),
              );
              SitumAr.sendNotificationToContentView();
            },
            child: Icon(Icons.notification_important),
          ),
        ),
      ],
    );
  }

  void onARViewMessage(ARViewController? controller, String? message) {
    debugPrint("Situm> AR> MESSAGE! $message");
  }

  void onARViewCreated(BuildContext context, ARViewController? controller) {    
    debugPrint("Situm> AR> onARViewCreated!");
    sendPOIs();
  }

  void onARViewReattached(ARViewController controller) {
    debugPrint("Situm> AR> REATTACHED!");
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

  void sendPOIs() {
    var sdk = SitumSdk();      
    sdk.fetchBuildingInfo(widget.buildingIdentifier).then((buildingInfo) {            
      var buildingInfoMap = buildingInfo.toMap();   
      //print("Building map:   ${buildingInfoMap["building"]}");
      
      var poisMap = buildingInfoMap["indoorPOIs"];        
      var width = buildingInfoMap["building"]["height"];        

      SitumAr.updatePOIs(poisMap, width).then((_) {          
      }).catchError((error) {
        print("Error updating POIs: $error");
      });
    });
  }

  void updateStatusArRequested() {
  setState(() {
    isArVisible = true;
    isMapCollapsed = false;
  });
  
  centerAction() {
    // Verificar si el ScrollController tiene clientes (es decir, está adjunto a un ScrollView)
    if (isArVisible && scrollController.hasClients) {
      scrollController.jumpTo(scrollController.position.maxScrollExtent * 2 / 5);
    } else {
      print("ScrollController no está adjunto a ninguna vista de scroll.");
    }
  }

  // Usa animationDurationWithDelay para mover el scroll que contiene el MapView
  Future.delayed(animationDurationWithDelay, centerAction);

  // Watchdog para asegurarse de que el ScrollController se actualiza correctamente
  Future.delayed(const Duration(milliseconds: 1500), centerAction);

  // Crear un mensaje de "AR Loading" que desaparece después de 10 segundos
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
