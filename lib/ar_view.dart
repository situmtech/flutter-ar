import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

// class ARViewWidget extends StatefulWidget {
//   @override
//   _ARWidgetState createState() => _ARWidgetState();
// }

// class _ARWidgetState extends State<ARViewWidget> {
//   @override
//   Widget build(BuildContext context) {
//     return AndroidView(
//       viewType: 'ARView',
//       creationParamsCodec: const StandardMessageCodec(),
//     );
//   }

//   @override
//   void initState() {
//     super.initState();
//     _requestPermissions();
//   }

//   Future<void> _requestPermissions() async {
//     var status = await Permission.camera.status;
//     if (!status.isGranted) {
//       await Permission.camera.request();
//     }
//   }
// }

///////////
const CHANNEL_ID = 'ARView';

class ARViewController {
  ARViewController._(
    ARView view,
    int id,
  )   : _view = view,
        _channel = MethodChannel('${CHANNEL_ID}_$id') {
    _channel.setMethodCallHandler(_methodCallHandler);
  }

  ARView _view;
  final MethodChannel _channel;

  Future<dynamic> _methodCallHandler(MethodCall call) async {
    switch (call.method) {
      case 'onARViewReattached':
        if (_view.onReattached != null) {
          _view.onReattached!(this);
        }
        return null;
      case 'onARViewMessage':
        if (_view.onMessage != null) {
          _view.onMessage!(this, call.arguments);
        }
        return null;
      default:
        throw UnimplementedError('Unimplemented method: ${call.method}');
    }
  }

  void pause() {
    _channel.invokeMethod('pause');
  }

  void resume() {
    _channel.invokeMethod('resume');
  }

  void send(
    String gameObjectName,
    String methodName,
    String message,
  ) {
    _channel.invokeMethod('send', {
      'gameObjectName': gameObjectName,
      'methodName': methodName,
      'message': message,
    });
  }
}

typedef void ARViewCreatedCallback(
  ARViewController? controller,
);
typedef void ARViewReattachedCallback(
  ARViewController controller,
);
typedef void ARViewMessageCallback(
  ARViewController controller,
  String? message,
);

class ARView extends StatefulWidget {
  const ARView({
    Key? key,
    this.onCreated,
    this.onReattached,
    this.onMessage,
  }) : super(key: key);

  final ARViewCreatedCallback? onCreated;
  final ARViewReattachedCallback? onReattached;
  final ARViewMessageCallback? onMessage;

  @override
  _ARViewState createState() => _ARViewState();
}

class _ARViewState extends State<ARView> {
  ARViewController? controller;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      await Permission.camera.request();
    }
  }

  @override
  void didUpdateWidget(ARView oldWidget) {
    super.didUpdateWidget(oldWidget);
    controller?._view = widget;
  }

  @override
  void dispose() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      controller?._channel?.invokeMethod('dispose');
    }
    controller?._channel?.setMethodCallHandler(null);
    super.dispose();
  }

  // https://github.com/flutter/flutter/wiki/Android-Platform-Views
  Widget _buildHybrid(BuildContext context) {
    print("Situm> Using hybrid components");
    return PlatformViewLink(
      viewType: CHANNEL_ID,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (params) {
        final AndroidViewController controller =
            PlatformViewsService.initSurfaceAndroidView(
          id: params.id,
          viewType: CHANNEL_ID,
          layoutDirection: TextDirection.ltr,
          creationParamsCodec: const StandardMessageCodec(),
          onFocus: () {
            params.onFocusChanged(true);
          },
        );
        controller
            .addOnPlatformViewCreatedListener(params.onPlatformViewCreated);
        controller.addOnPlatformViewCreatedListener(onPlatformViewCreated);
        controller.create();
        return controller;
      },
    );
  }

  Widget _buildNormal() {
    return AndroidView(
      viewType: CHANNEL_ID,
      creationParamsCodec: const StandardMessageCodec(),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        //return _buildHybrid(context);
        return _buildNormal();
        break;
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: CHANNEL_ID,
          onPlatformViewCreated: onPlatformViewCreated,
        );
        break;
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  void onPlatformViewCreated(int id) {
    controller = ARViewController._(widget, id);
    if (widget.onCreated != null) {
      widget.onCreated!(controller);
    }
  }
}
