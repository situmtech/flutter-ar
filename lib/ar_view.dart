import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class ARViewWidget extends StatefulWidget {
  @override
  _ARViewWidgetState createState() => _ARViewWidgetState();
}

class _ARViewWidgetState extends State<ARViewWidget> {
  @override
  void initState() {
    super.initState();
    // Lógica cuando el widget se active
    debugPrint(">>ARViewWidget se ha activado");
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  void dispose() {
    // Lógica cuando el widget se detenga
    debugPrint(">>ARViewWidget se ha detenido");
    // Puedes agregar más lógica aquí
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const String viewType = 'ARView';
    const Map<String, dynamic> creationParams = <String, dynamic>{};
    debugPrint(">>ARViewWidget build");
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}
