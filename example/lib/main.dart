import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:situm_flutter_ar/ar.dart';
import 'package:situm_ar_example/config.dart';
import 'package:situm_flutter/sdk.dart';
import 'package:situm_flutter/wayfinding.dart';

void main() => runApp(const NavigationBarApp());

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const NavigationBase(),
    );
  }
}

class NavigationBase extends StatefulWidget {
  const NavigationBase({super.key});

  @override
  State<NavigationBase> createState() => _NavigationBaseState();
}

class _NavigationBaseState extends State<NavigationBase> {
  ARController arController = ARController();

  @override
  void initState() {
    super.initState();
    var sdk = SitumSdk();
    sdk.init(null, situmApiKey);

    // Location:
    sdk.onLocationUpdate((location) {
      // debugPrint("Situm> SDK> Received location.");
      arController.setLocation(location);
    });

    sdk.onLocationError((error) {
      debugPrint("Situm> SDK> ERROR: ${error.message}");
    });

    sdk.onLocationStatus((status) {
      debugPrint("Situm> SDK> STATUS: $status");
    });

    // Navigation:
    sdk.onNavigationCancellation(() {
      debugPrint("Situm> SDK> CANCEL NAVIGATION");
      arController.setNavigationCancelled();
    });

    sdk.onNavigationDestinationReached(() {
      debugPrint("Situm> SDK> NAVIGATION DESTINATION REACHED");
      arController.setNavigationDestinationReached();
    });

    sdk.onNavigationOutOfRoute(() {
      debugPrint("Situm> SDK> NAVIGATION USER OUT OF ROUTE");
      arController.setNavigationOutOfRoute();
    });

    sdk.onNavigationProgress((progress) {
      debugPrint("Situm> SDK> NAVIGATION PROGRESS");
      arController.setNavigationProgress(progress);
    });

    sdk.onNavigationStart((route) {
      debugPrint("Situm> SDK> NAVIGATION START");
      arController.setNavigationStart(route);
    });

    startPositioning();
  }

  void startPositioning() async {
    await requestPermissions();
    SitumSdk().requestLocationUpdates(LocationRequest(
      // Copy config.dart.example if you haven't already.
      buildingIdentifier: buildingIdentifier,
      useDeadReckoning: false,
      useForegroundService: true,
      foregroundServiceNotificationOptions:
          ForegroundServiceNotificationOptions(
        showStopAction: true,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ARWidget(
        buildingIdentifier: buildingIdentifier,
        onCreated: onUnityViewCreated,
        onPopulated: onUnityViewPopulated,
        onDisposed: onUnityViewDisposed,
        arHeightRatio: 0.999,
        mapView: MapView(
          key: const Key("situm_map"),
          configuration: MapViewConfiguration(
            // Your Situm credentials.
            // Copy config.dart.example if you haven't already.
            situmApiKey: situmApiKey,
            // Set your building identifier:
            buildingIdentifier: buildingIdentifier,
            viewerDomain: "https://map-viewer.situm.com",
            apiDomain: "https://dashboard.situm.com",
            remoteIdentifier: remoteIdentifier,
            persistUnderlyingWidget: true,
          ),
          onLoad: onMapViewLoad,
        ),
      ),
    );
  }

  void onMapViewLoad(MapViewController controller) {
    // Notifies the AR module that the MapView has been loaded, ensuring
    // seamless integration between both.
    arController.onMapViewLoad(controller);
    // UI callbacks:
    controller.onPoiSelected((poiSelectedResult) {
      arController.setSelectedPoi(poiSelectedResult.poi);
    });
  }

  void onUnityViewCreated() {
    debugPrint("Situm> AR> UNITY VIEW CREATED.");
  }

  void onUnityViewPopulated() {
    debugPrint("Situm> AR> BUILDING INFO HAS BEEN SENT TO THE AR MODULE.");
  }

  void onUnityViewDisposed() {
    debugPrint("Situm> AR> UNITY VIEW DISPOSED.");
  }

  /// Example of a function that request permissions and check the result:
  Future<bool> requestPermissions() async {
    var permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.camera,
    ];
    if (Platform.isAndroid) {
      permissions.addAll([
        Permission.storage,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }
}
