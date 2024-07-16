import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ARViewWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("ARView Example"),
      ),
      body: Center(
        child: AndroidView(
          viewType: 'ARView',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{},
          creationParamsCodec: const StandardMessageCodec(),
        ),
      ),
    );
  }
}
