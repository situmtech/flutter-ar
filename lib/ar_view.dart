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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _build(context),
    );
  }

  Widget _build(BuildContext context) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // return AndroidView(
        //   viewType: CHANNEL_ID,
        //   creationParamsCodec: const StandardMessageCodec(),
        //   onPlatformViewCreated: onPlatformViewCreated,
        // );

        return PlatformViewLink(
          viewType: CHANNEL_ID,
          surfaceFactory: (context, controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <Factory<
                  OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (params) {
            // WARNING! AR SurfaceView will fight with
            // initExpensiveAndroidView while using Skia rendering engine. Using
            // Impeller the result is similar for both methods (for now, only
            // simple appreciation tests have been done - no profiling).
            final AndroidViewController controller =
                PlatformViewsService.initAndroidView(
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
    if (widget.onCreated != null) {
      widget.onCreated!(controller);
    }
  }
}
