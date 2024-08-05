import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:situm_ar_example/config.dart';
import 'package:situm_flutter/sdk.dart';
import 'package:situm_flutter/wayfinding.dart';
import 'package:situm_flutter_ar/ar.dart';

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
  Location? location;
  int lastLocationUpdate = 0;
  int? locationDiff;
  final _streamSubscriptions = <StreamSubscription<dynamic>>[];
  MagnetometerEvent? _magnetometerEvent;
  GyroscopeEvent? _gyroscopeEvent;
  AccelerometerEvent? _accelerometerEvent;

  @override
  void dispose() {
    super.dispose();
    for (final subscription in _streamSubscriptions) {
      subscription.cancel();
    }
  }

  @override
  void initState() {
    super.initState();
    var sdk = SitumSdk();
    sdk.init();
    sdk.setDashboardURL(apiDomain);
    sdk.setApiKey(situmApiKey);

    SitumSdk().onLocationStatus((status) {
      debugPrint("Situm> AR> Location> $status");
    });

    SitumSdk().onLocationError((error) {
      debugPrint("Situm> AR> Location> ${error.code}: ${error.message}");
    });

    SitumSdk().onLocationUpdate((location) {
      setState(() {
        this.location = location;
        locationDiff =
            DateTime.timestamp().millisecondsSinceEpoch - lastLocationUpdate;
        lastLocationUpdate = DateTime.timestamp().millisecondsSinceEpoch;
      });
    });

    _streamSubscriptions.add(
      magnetometerEventStream(samplingPeriod: const Duration(milliseconds: 100))
          .listen(
        (MagnetometerEvent event) {
          setState(() {
            _magnetometerEvent = event;
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Magnetometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );

    _streamSubscriptions.add(
      gyroscopeEventStream(samplingPeriod: const Duration(milliseconds: 100))
          .listen(
        (GyroscopeEvent event) {
          setState(() {
            _gyroscopeEvent = event;
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Gyroscope Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );

    _streamSubscriptions.add(
      accelerometerEventStream(
              samplingPeriod: const Duration(milliseconds: 100))
          .listen(
        (AccelerometerEvent event) {
          setState(() {
            _accelerometerEvent = event;
          });
        },
        onError: (e) {
          showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  title: Text("Sensor Not Found"),
                  content: Text(
                      "It seems that your device doesn't support Accelerometer Sensor"),
                );
              });
        },
        cancelOnError: true,
      ),
    );

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
        child: Column(
          children: [
            Table(
              children: [
                const TableRow(children: [
                  Text("SDK"),
                  Text("Gyro"),
                  Text("Acc"),
                  Text("Mgn")
                ]),
                TableRow(children: [
                  Text(
                    location?.bearing?.radians.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _gyroscopeEvent?.x.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _accelerometerEvent?.x.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _magnetometerEvent?.x.toStringAsFixed(2) ?? '?',
                  ),
                ]),
                TableRow(children: [
                  Text(
                    "${locationDiff?.toString() ?? '?'} ms",
                  ),
                  Text(
                    _gyroscopeEvent?.y.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _accelerometerEvent?.y.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _magnetometerEvent?.y.toStringAsFixed(2) ?? '?',
                  ),
                ]),
                TableRow(children: [
                  Text(
                    location?.cartesianCoordinate.x.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _gyroscopeEvent?.z.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _accelerometerEvent?.z.toStringAsFixed(2) ?? '?',
                  ),
                  Text(
                    _magnetometerEvent?.z.toStringAsFixed(2) ?? '?',
                  ),
                ])
              ],
            ),
            Expanded(
              child: ARWidget(
                buildingIdentifier: buildingIdentifier,
                mapboxAccessToken: mapboxAccessToken,
                apiDomain: apiDomain,
                onCreated: onUnityViewCreated,
                onPopulated: onUnityViewPopulated,
                onDisposed: onUnityViewDisposed,
                enable3DAmbiences: true,
                debugMode: true,
                mapView: MapView(
                  key: const Key("situm_map"),
                  configuration: MapViewConfiguration(
                    situmApiKey: situmApiKey,
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
          ],
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
      debugPrint(
          "Situm> AR> Selected POI: ${poiSelectedResult.poi.identifier}");
    });
    // controller.navigateToPoi("536822");
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
