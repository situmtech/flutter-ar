part of 'ar.dart';

const CHANNEL_ID = 'SitumARView';

class ARView extends StatefulWidget {
  const ARView({
    super.key,
    this.onCreated,
  });

  final ARViewCreatedCallback? onCreated;

  @override
  State<ARView> createState() => _ARViewState();
}

class _ARViewState extends State<ARView> {
  final ARController controller = ARController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(ARView oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    controller.unload();
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
      onPlatformViewCreated: onPlatformViewCreated,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _buildHybrid(context);
        // return _buildNormal();
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: CHANNEL_ID,
          onPlatformViewCreated: onPlatformViewCreated,
        );
      default:
        throw UnsupportedError('Unsupported platform: $defaultTargetPlatform');
    }
  }

  void onPlatformViewCreated(int id) async {
    await controller.load();
    if (widget.onCreated != null) {
      widget.onCreated!(controller);
    }
  }
}
