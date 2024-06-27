part of 'ar.dart';

// TODO: this file has been temporarily imported from a testing project. It needs review as it is a mess...

const ACCURACY_TH = 6.0;
const JUMP_TH = 4.0;
const WALKED_TH = 7.0;
const NO_HAS_BEARING_TH = 3;

const ENJOY_REFRESS_DATA = 1000;

const EXPLORATION_REFRESS_DATA = 5;
const EXPLORATION_DISTANCE_LIMIT_DATA = 5.0;
const EXPLORATION_ANGLE_LIMIT_DATA = 30;
const EXPLORATION_ACCURACY_LIMIT_DATA = 6;
const EXPLORATION_CAMERA_LIMIT = 20.0;

const NAVIGATION_REFRESS_DATA = 3;
const NAVIGATION_DISTANCE_LIMIT_DATA = -0.1;
const NAVIGATION_ANGLE_LIMIT_DATA = 30;
const NAVIGATION_ACCURACY_LIMIT_DATA = 6;
const NAVIGATION_CAMERA_LIMIT = 20.0;

const DYNAMIC_STABLE_REFRESH_TIME = 30;
const DYNAMIC_UNSTABLE_REFRESH_TIME = 5; //30;
const DYNAMIC_YAW_DIFF_STD_THRESHOLD = 15.0;
const DYNAMIC_TIME_TO_REFRESH = 3;
const DYNAMIC_TIME_TO_KEEP_REFRESHING = 10;
const DYNAMIC_LOCATION_BUFFER_SIZE = 10;

const REFRESH = true;
const ODO_DIFFERENCE_SENSIBILITY = 4;
const ARROW_DISTANCE_TO_SKIP_NODE = 12.0;

enum DebugMode {
  deactivated,
  alertVisibilityParams, //0 Navigation Thresholds (accuracy, jump, distance, noBearing)
  unityParams, //1 Unity Thresholds (refresh_data, distance_max_data, angle_limit_data, accuracy_limit_data)
}

class ARModeDebugValues {
  static ValueNotifier<DebugMode> debugMode =
      ValueNotifier<DebugMode>(DebugMode.alertVisibilityParams);

  static ValueNotifier<ARMode> arModeNotifier =
      ValueNotifier<ARMode>(DEFAULT_AR_MODE);

  // Value Notifiers to listen in params to set the accuracy alert

  static ValueNotifier<double> accuracyThreshold =
      ValueNotifier<double>(ACCURACY_TH);
  static ValueNotifier<double> jumpThreshold = ValueNotifier<double>(JUMP_TH);
  static ValueNotifier<double> walkedThreshold =
      ValueNotifier<double>(WALKED_TH);
  static ValueNotifier<int> noHasBearingThreshold =
      ValueNotifier<int>(NO_HAS_BEARING_TH);

  static ValueNotifier<String> debugVariables = ValueNotifier<String>('---');

  // Value Notifiers to listen changes in unity params

  static ValueNotifier<int> enjoyRefreshData =
      ValueNotifier<int>(ENJOY_REFRESS_DATA);

  // Value Notifiers Dynamic params
  static ValueNotifier<int> dynamicStableRefreshTime =
      ValueNotifier<int>(DYNAMIC_STABLE_REFRESH_TIME);
  static ValueNotifier<int> dynamicUnstableRefreshTime =
      ValueNotifier<int>(DYNAMIC_UNSTABLE_REFRESH_TIME);
  static ValueNotifier<double> dynamicYawDiffStdThreshold =
      ValueNotifier<double>(DYNAMIC_YAW_DIFF_STD_THRESHOLD);
  static ValueNotifier<int> dynamicTimeToRefresh =
      ValueNotifier<int>(DYNAMIC_TIME_TO_REFRESH);
  static ValueNotifier<int> dynamicTimeToKeepRefreshing =
      ValueNotifier<int>(DYNAMIC_TIME_TO_KEEP_REFRESHING);
  static ValueNotifier<int> locationBufferSize =
      ValueNotifier<int>(DYNAMIC_LOCATION_BUFFER_SIZE);

  static ValueNotifier<int> explorationRefreshData =
      ValueNotifier<int>(EXPLORATION_REFRESS_DATA);
  static ValueNotifier<double> explorationDistanceLimitData =
      ValueNotifier<double>(EXPLORATION_DISTANCE_LIMIT_DATA);
  static ValueNotifier<int> explorationAngleLimitData =
      ValueNotifier<int>(EXPLORATION_ANGLE_LIMIT_DATA);
  static ValueNotifier<int> explorationAccuracyLimitDada =
      ValueNotifier<int>(EXPLORATION_ACCURACY_LIMIT_DATA);
  static ValueNotifier<double> explorationCameraLimit =
      ValueNotifier<double>(EXPLORATION_CAMERA_LIMIT);

  static ValueNotifier<int> navigationRefreshData =
      ValueNotifier<int>(NAVIGATION_REFRESS_DATA);
  static ValueNotifier<double> navigationDistanceLimitData =
      ValueNotifier<double>(NAVIGATION_DISTANCE_LIMIT_DATA);
  static ValueNotifier<int> navigationAngleLimitData =
      ValueNotifier<int>(NAVIGATION_ANGLE_LIMIT_DATA);
  static ValueNotifier<int> navigationAccuracyLimitDada =
      ValueNotifier<int>(NAVIGATION_ACCURACY_LIMIT_DATA);
  static ValueNotifier<double> navigationCameraLimit =
      ValueNotifier<double>(NAVIGATION_CAMERA_LIMIT);

  static ValueNotifier<bool> refresh = ValueNotifier<bool>(REFRESH);

  static ValueNotifier<int> odoDifferenceSensibility =
      ValueNotifier<int>(ODO_DIFFERENCE_SENSIBILITY);
  static ValueNotifier<double> dynamicRefreshThreshold =
      ValueNotifier<double>(0);

  static ValueNotifier<bool> showRouteElements = ValueNotifier<bool>(false);
  static ValueNotifier<double> arrowDistanceToSkipNode =
      ValueNotifier<double>(ARROW_DISTANCE_TO_SKIP_NODE);

  static ValueNotifier<bool> nextIndicationUp = ValueNotifier<bool>(false);
  static ValueNotifier<bool> nextIndicationChangeFloor =
      ValueNotifier<bool>(false);

  static set arMode(ARMode arMode) {
    arModeNotifier.value = arMode;
  }

  static ARModeUnityParams getUnityParamsForMode(ARMode arMode) {
    switch (arMode) {
      case ARMode.enjoy:
        return ARModeUnityParams(
            enjoyRefreshData.value,
            explorationDistanceLimitData.value,
            explorationAngleLimitData.value,
            explorationAccuracyLimitDada.value,
            explorationCameraLimit.value);
      case ARMode.relaxed:
        return ARModeUnityParams(
            explorationRefreshData.value,
            explorationDistanceLimitData.value,
            explorationAngleLimitData.value,
            explorationAccuracyLimitDada.value,
            explorationCameraLimit.value);
      case ARMode.strict:
        return ARModeUnityParams(
            navigationRefreshData.value,
            navigationDistanceLimitData.value,
            navigationAngleLimitData.value,
            navigationAccuracyLimitDada.value,
            navigationCameraLimit.value);
      case ARMode.dynamicRefreshRate:
        return ARModeUnityParams(
            navigationRefreshData.value,
            navigationDistanceLimitData.value,
            navigationAngleLimitData.value,
            navigationAccuracyLimitDada.value,
            navigationCameraLimit.value);
    }
  }
}

class ARModeUnityParams {
  int refreshData;
  double distanceLimit;
  int angleLimit;
  int accuracyLimit;
  double cameraLimit;

  ARModeUnityParams(this.refreshData, this.distanceLimit, this.angleLimit,
      this.accuracyLimit, this.cameraLimit);

  @override
  String toString() {
    return 'ARModeUnityParams('
        'refreshData: $refreshData, '
        'distanceLimit: $distanceLimit, '
        'angleLimit: $angleLimit, '
        'accuracyLimit: $accuracyLimit, '
        'cameraLimit: $cameraLimit)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ARModeUnityParams &&
          runtimeType == other.runtimeType &&
          refreshData == other.refreshData &&
          distanceLimit == other.distanceLimit &&
          angleLimit == other.angleLimit &&
          accuracyLimit == other.accuracyLimit &&
          cameraLimit == other.cameraLimit;
}

class ARDebugUI {
  UnityViewController? _controller;

  set controller(UnityViewController? controller) {
    _controller = controller;
    //Adding listeners than will only send their modified data to Unity if we are in the proper ARMode(exploration or navigation)
    addUnityParamsListener(ARModeDebugValues.explorationRefreshData,
        "SendRefressData", ARMode.relaxed);
    addUnityParamsListener(ARModeDebugValues.explorationDistanceLimitData,
        "SendDistanceLimitData", ARMode.relaxed);
    addUnityParamsListener(ARModeDebugValues.explorationAngleLimitData,
        "SendAngleLimitData", ARMode.relaxed);
    addUnityParamsListener(ARModeDebugValues.explorationAccuracyLimitDada,
        "SendAccurancyLimitData", ARMode.relaxed);
    addUnityParamsListener(ARModeDebugValues.explorationCameraLimit,
        "SendCameraLimit", ARMode.relaxed);

    addUnityParamsListener(ARModeDebugValues.navigationRefreshData,
        "SendRefressData", ARMode.strict);
    addUnityParamsListener(ARModeDebugValues.navigationDistanceLimitData,
        "SendDistanceLimitData", ARMode.strict);
    addUnityParamsListener(ARModeDebugValues.navigationAngleLimitData,
        "SendAngleLimitData", ARMode.strict);
    addUnityParamsListener(ARModeDebugValues.navigationAccuracyLimitDada,
        "SendAccurancyLimitData", ARMode.strict);
    addUnityParamsListener(ARModeDebugValues.navigationCameraLimit,
        "SendCameraLimit", ARMode.strict);
  }

  //
  //CREATE DEBUG WINDOWS
  //1. ALERT LOW PRECISION
  //

  List<Widget> createAlertVisibilityParamsDebugWidgets() {
    return [
      createDebugButton(ARModeDebugValues.accuracyThreshold,
          DebugMode.alertVisibilityParams, 'AccTh', 0.1, 220, 5),
      createDebugButton(ARModeDebugValues.jumpThreshold,
          DebugMode.alertVisibilityParams, 'JumpTh', 0.1, 220, 150),
      createDebugButton(ARModeDebugValues.walkedThreshold,
          DebugMode.alertVisibilityParams, 'WalkTh', 0.1, 280, 5),
      createDebugButton(ARModeDebugValues.noHasBearingThreshold,
          DebugMode.alertVisibilityParams, 'NoBearTh', 1, 280, 150),
      createDebugButton(ARModeDebugValues.debugMode,
          DebugMode.alertVisibilityParams, 'Debug Mode', 1.0, 400, 5,
          width: 200),
      ValueListenableBuilder<DebugMode>(
          valueListenable: ARModeDebugValues.debugMode,
          builder: (context, value, child) {
            return Visibility(
                visible: (value == DebugMode.alertVisibilityParams),
                child: Positioned(
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(77, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: ARModeDebugValues.debugVariables,
                      builder: (context, value, child) => Text(
                        value,
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ));
          }),
    ];
  }

  //
  //CREATE DEBUG WINDOWS
  //2. UNITY PARAMS
  //

  List<Widget> createUnityParamsDebugWidgets() {
    List<Widget> widgets = [];

    widgets.add(createDebugButton(ARModeDebugValues.explorationCameraLimit,
        DebugMode.unityParams, 'ExpCamera', 0.5, 40, 5));
    widgets.add(createDebugButton(ARModeDebugValues.navigationCameraLimit,
        DebugMode.unityParams, 'NavCamera', 0.5, 40, 150));
    widgets.add(createDebugButton(ARModeDebugValues.explorationRefreshData,
        DebugMode.unityParams, 'ExpRefresh', 1, 100, 5));
    widgets.add(createDebugButton(ARModeDebugValues.navigationRefreshData,
        DebugMode.unityParams, 'NavRefresh', 1, 100, 150));
    widgets.add(createDebugButton(
        ARModeDebugValues.explorationDistanceLimitData,
        DebugMode.unityParams,
        'ExpDist',
        0.2,
        160,
        5));
    widgets.add(createDebugButton(ARModeDebugValues.navigationDistanceLimitData,
        DebugMode.unityParams, 'NavDist', 0.2, 160, 150));
    widgets.add(createDebugButton(ARModeDebugValues.explorationAngleLimitData,
        DebugMode.unityParams, 'ExpAngle', 1, 220, 5));
    widgets.add(createDebugButton(ARModeDebugValues.navigationAngleLimitData,
        DebugMode.unityParams, 'NavAngle', 1, 220, 150));
    widgets.add(createDebugButton(
        ARModeDebugValues.explorationAccuracyLimitDada,
        DebugMode.unityParams,
        'ExpAcc',
        1,
        280,
        5));
    widgets.add(createDebugButton(ARModeDebugValues.navigationAccuracyLimitDada,
        DebugMode.unityParams, 'NavAcc', 1, 280, 150));
    widgets.add(createDebugButton(ARModeDebugValues.debugMode,
        DebugMode.unityParams, 'Debug Mode', 1.0, 400, 5,
        width: 200));

    widgets.add(
      ValueListenableBuilder<DebugMode>(
          valueListenable: ARModeDebugValues.debugMode,
          builder: (context, value, child) {
            return Visibility(
                visible: (value == DebugMode.unityParams),
                child: Positioned(
                  bottom: 340,
                  left: 160,
                  child: Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color.fromARGB(77, 107, 212, 247).withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: ARModeDebugValues.arModeNotifier,
                      builder: (context, value, child) => Text(
                        value.toString().split('.').last,
                        style: TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                ));
          }),
    );

    return widgets;
  }

  Widget createButtonRefresh(ValueNotifier<bool> refresh, DebugMode mode,
      String label, double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      child: ElevatedButton(
        onPressed: () {
          _controller?.send("MessageManager", "ForceReposition", "null");
        },
        child: Text(label),
      ),
    );
  }

  String showElements = "arrow";
  Widget createButtonSwitchPath(ValueNotifier<bool> refresh, DebugMode mode,
      String label, double left, double top, double size) {
    return Positioned(
      left: left,
      top: top,
      child: ElevatedButton(
        onPressed: () {
          if (showElements == "arrow") {
            showElements = "route";
            _controller?.send(
                "MessageManager", "SendDisableArrowGuide", "null");
            _controller?.send(
                "MessageManager", "SendShowRouteElements", "null");
          } else if (showElements == "route") {
            showElements = "route_and_arrow";
            _controller?.send(
                "MessageManager", "SendShowRouteElements", "null");
            _controller?.send("MessageManager", "SendEnableArrowGuide", "null");
          } else if (showElements == "route_and_arrow") {
            showElements = "nothing";
            _controller?.send(
                "MessageManager", "SendHideRouteElements", "null");
            _controller?.send("MessageManager", "SendEnableArrowGuide", "null");
          } else if (showElements == "nothing") {
            showElements = "arrow";
            _controller?.send(
                "MessageManager", "SendHideRouteElements", "null");
            _controller?.send(
                "MessageManager", "SendDisableArrowGuide", "null");
          }
        },
        child: Text(label),
      ),
    );
  }

  List<Widget> createWidgetRefresh() {
    return [
      createButtonSwitchPath(ARModeDebugValues.refresh,
          DebugMode.alertVisibilityParams, 'Show Route', 0, 500, 5),
      createButtonRefresh(ARModeDebugValues.refresh,
          DebugMode.alertVisibilityParams, 'Refresh', 0, 450, 5),
      createDebugButton(ARModeDebugValues.arrowDistanceToSkipNode,
          DebugMode.alertVisibilityParams, 'distance to skip node', 1, 400, 5),
      ValueListenableBuilder<DebugMode>(
          valueListenable: ARModeDebugValues.debugMode,
          builder: (context, value, child) {
            return Visibility(
                visible: (value == DebugMode.alertVisibilityParams),
                child: Positioned(
                  //bottom: 10,
                  top: 100,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(77, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: ARModeDebugValues.debugVariables,
                      builder: (context, value, child) => Text(
                        value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ));
          }),
    ];
  }

  List<Widget> createDynamicUnityParamsWidgets() {
    return [
      createDebugButton(ARModeDebugValues.navigationAccuracyLimitDada,
          DebugMode.alertVisibilityParams, 'NavAcc', 1, 450, 5),
      createDebugButton(ARModeDebugValues.navigationDistanceLimitData,
          DebugMode.alertVisibilityParams, 'NavDist', 0.2, 400, 5),
      createDebugButton(ARModeDebugValues.dynamicStableRefreshTime,
          DebugMode.alertVisibilityParams, 'stable refresh time', 5, 350, 5),
      createDebugButton(ARModeDebugValues.walkedThreshold,
          DebugMode.alertVisibilityParams, 'WalkTh', 1, 300, 5),
      createDebugButton(ARModeDebugValues.dynamicYawDiffStdThreshold,
          DebugMode.alertVisibilityParams, 'yawDiffStdTh', 1.0, 250, 5),
      createDebugButton(ARModeDebugValues.dynamicTimeToRefresh,
          DebugMode.alertVisibilityParams, 'time to refresh', 1, 200, 5),
      createDebugButton(
          ARModeDebugValues.dynamicTimeToKeepRefreshing,
          DebugMode.alertVisibilityParams,
          'time to keep refreshing',
          1,
          150,
          5),
      createDebugButton(ARModeDebugValues.locationBufferSize,
          DebugMode.alertVisibilityParams, 'locations buffer size ', 1, 500, 5),
      ValueListenableBuilder<DebugMode>(
          valueListenable: ARModeDebugValues.debugMode,
          builder: (context, value, child) {
            return Visibility(
                visible: (value == DebugMode.alertVisibilityParams),
                child: Positioned(
                  //bottom: 10,
                  top: 10,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(77, 255, 255, 255),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ValueListenableBuilder(
                      valueListenable: ARModeDebugValues.debugVariables,
                      builder: (context, value, child) => Text(
                        value,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ));
          }),
    ];
  }

  ValueListenableBuilder createDebugButton(
      ValueNotifier notifier,
      DebugMode visibleDebugMode,
      String buttonTitle,
      num increment,
      double bottom,
      double left,
      {double width = 200}) {
    return ValueListenableBuilder(
        valueListenable: ARModeDebugValues.debugMode,
        builder: (context, value, child) {
          return Visibility(
              visible: value == visibleDebugMode,
              child: Positioned(
                bottom: bottom,
                left: left,
                width: width,
                child: Card(
                  elevation: 4.0,
                  color: Color.fromARGB(255, 241, 245, 241).withOpacity(0.7),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () {
                          if (notifier.value is bool) {
                            notifier.value = false;
                          } else if (notifier.value is DebugMode) {
                            notifier.value = DebugMode.alertVisibilityParams;
                          } else {
                            notifier.value -= increment;
                          }
                        },
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: notifier,
                        builder: (context, value, child) {
                          return Text(
                              '$buttonTitle\n${_debugButtonTitle(value)}',
                              style: const TextStyle(
                                fontSize: 8,
                              ));
                        },
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () {
                          if (notifier.value is bool) {
                            notifier.value = true;
                          } else if (notifier.value is DebugMode) {
                            notifier.value = DebugMode.unityParams;
                          } else {
                            notifier.value += increment;
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ));
        });
  }

  String _debugButtonTitle(dynamic value) {
    if (value is bool) {
      return '$value';
    } else if (value is DebugMode) {
      return value.toString().split('.').last;
    } else {
      return '${value.toStringAsFixed(1)}';
    }
  }

  void addUnityParamsListener(
      ValueNotifier param, String unityMessage, ARMode? arModeToSendMessage) {
    param.addListener(() {
      if (arModeToSendMessage != null &&
          ARModeDebugValues.arModeNotifier.value != arModeToSendMessage) {
        return;
      }
      _controller?.send("MessageManager", unityMessage, param.value.toString());
    });
  }
}
