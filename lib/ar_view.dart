import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

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

  Widget _buildNormal(){
    return AndroidView( viewType: CHANNEL_ID,
    creationParamsCodec: const StandardMessageCodec(),
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildNormal();
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: CHANNEL_ID,
          onPlatformViewCreated: onPlatformViewCreated,
        );
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
