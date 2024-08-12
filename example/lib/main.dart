import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:situm_ar_example/config.dart';
import 'package:situm_flutter/sdk.dart';
import 'package:situm_flutter/wayfinding.dart';
import 'package:situm_flutter_ar/ar.dart';

void main() => runApp(const NavigationBarApp());

class NavigationBarApp extends StatelessWidget {
  const NavigationBarApp({super.key});

  @override
  Widget build(BuildContext context) {
    requestPermissions();
    return MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: const NavigationBase(),
    );
  }

  Future<bool> requestPermissions() async {
    var permissions = <Permission>[
      Permission.locationWhenInUse,
      Permission.camera,
    ];
    if (Platform.isAndroid) {
      permissions.addAll([
        //Permission.storage,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
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
    sdk.init();
    sdk.setDashboardURL(apiDomain);
    sdk.setApiKey(situmApiKey);

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
      motionMode: MotionMode.byFootVisualOdometry,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ARWidget(
          buildingIdentifier: buildingIdentifier,
          apiDomain: apiDomain,
          onCreated: onUnityViewCreated,
          onPopulated: onUnityViewPopulated,
          onDisposed: onUnityViewDisposed,
          enable3DAmbiences: true,
          debugMode: true,
          mapView: MapView(
            key: const Key("situm_map"),
            configuration: MapViewConfiguration(
              // Your Situm credentials.
              // Copy config.dart.example if you haven't already.
              situmApiKey: situmApiKey,
              // Set your building identifier:
              buildingIdentifier: buildingIdentifier,
              viewerDomain: viewerDomain,
              apiDomain: apiDomain,
              remoteIdentifier: remoteIdentifier,
              persistUnderlyingWidget: true,
            ),
            onLoad: onMapViewLoad,
          ),
        ),
      ),
    );
  }

  void onMapViewLoad(MapViewController controller) {
    // Notifies the AR module that the MapView has been loaded, ensuring
    // seamless integration between both.
    arController.onMapViewLoad(controller);
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
        //Permission.storage,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ]);
    }
    Map<Permission, PermissionStatus> statuses = await permissions.request();
    return statuses.values.every((status) => status.isGranted);
  }
}
