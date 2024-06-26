part of 'ar.dart';

const LOCATION_BUFFER_SIZE = 10;

class _ARPosQuality extends StatefulWidget {
  final Function(_ARPosQualityState) onCreate;

  const _ARPosQuality({
    super.key,
    required this.onCreate,
  });

  @override
  _ARPosQualityState createState() => _ARPosQualityState();
}

class _ARPosQualityState extends State<_ARPosQuality> {
  double avgLocAccuracy = -1.0;
  double distanceWalked = -1.0;
  double biggestJump = -1.0;
  int countNoHasBearings = 0;
  bool hasBearing = false;
  int debugModeCount = 0;

  List<Location> sdkLocations = [];
  bool userNeedsToWalk = true;

  bool showARAlertWidget = true;

  int refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
  bool hasToRefresh = true;
  int waitToRefreshTimer = 0;
  int keepRefreshingTimer = 0;
  double yawDiffStd = 0;

  @override
  void initState() {
    super.initState();
    widget.onCreate.call(this);
  }

  @override
  Widget build(BuildContext context) {
    return const Visibility(
      // TODO: move logic to another component, remove this widget.
      visible: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: IntrinsicHeight(
          child: Card(
            elevation: 4.0,
            margin: EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Colors.orange,
                        size: 20.0,
                      ),
                      SizedBox(width: 8.0),
                      Text(
                        'Low quality AR',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.0,
                        ),
                      )
                    ],
                  ),
                  SizedBox(height: 6.0),
                  Text(
                    'Please keep walking through a calibrated area',
                    style: TextStyle(fontSize: 13.0),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void updateLocation(Location location) {
    sdkLocations.add(location);
    if (sdkLocations.length > LOCATION_BUFFER_SIZE) {
      sdkLocations.removeAt(0);
    }

    var converged = false;
    var hasWalked = false;

    if (sdkLocations.length == LOCATION_BUFFER_SIZE) {
      converged = _enoughARQuality(sdkLocations);
      hasWalked = _enoughARMovement(sdkLocations);
    }

    updateDynamicARParams(sdkLocations);

    if (!converged) {
      userNeedsToWalk = true;
    }

    var goodARQuality = converged;

    if (userNeedsToWalk) {
      goodARQuality = converged && hasWalked;
      if (goodARQuality) {
        // No need to walk if converged and already walked
        userNeedsToWalk = false;
      }
    }

    setState(() {
      showARAlertWidget = !goodARQuality;
    });

    var locationMap = location.toMap();
    locationMap["timestamp"] = -1;

    ARModeDebugValues.debugVariables.value = """
        Locations Number: ${sdkLocations.length} 
        Walked: ${distanceWalked.toStringAsFixed(1)} Th: ${ARModeDebugValues.walkedThreshold.value.toStringAsFixed(1)}
        ----
        yawDiffStd: $yawDiffStd,
        Dynamic params:
         refreshData: $refreshData, 
         distanceLimitData: ${ARModeDebugValues.navigationDistanceLimitData.value}, 
         hasToRefresh: $hasToRefresh,
         waitToRefreshTimer: $waitToRefreshTimer,
         keepRefreshingTimer: $keepRefreshingTimer,
        ---
        accuracyLimitData: ${ARModeDebugValues.navigationAccuracyLimitDada.value}
        ---
        converged: $converged
        hasWalked: $hasWalked
        goodARQuality: $goodARQuality
        """;
  }

  void updateDynamicARParams(List<Location> locations) {
    if (locations.length < ARModeDebugValues.locationBufferSize.value ||
        !this.allLocationsInSameFloor(locations)) {
      this.refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
      distanceWalked = 0;
      return;
    }

    bool hasWalked = _enoughARMovement(locations);
    bool isYawStable = _isYawStable(locations);

    if (!isYawStable) {
      hasToRefresh = true;
    }
    updateKeepRefreshingTimer(isYawStable && hasWalked);
    updateWaitToRefreshTimer();
    updateRefreshRate(isYawStable && hasWalked);
  }

  bool _isYawStable(sdkLocations) {
    // Check yaw std
    yawDiffStd = calculateAngleDifferencesStandardDeviation(sdkLocations);
    yawDiffStd = yawDiffStd * 180 / pi;
    if (yawDiffStd < (ARModeDebugValues.dynamicYawDiffStdThreshold.value)) {
      return true;
    } else {
      return false;
    }
  }

  bool isRefreshing() {
    return this.refreshData ==
        ARModeDebugValues.dynamicUnstableRefreshTime.value;
  }

  void updateWaitToRefreshTimer() {
    if (hasToRefresh &&
        waitToRefreshTimer < ARModeDebugValues.dynamicTimeToRefresh.value &&
        !isRefreshing()) {
      waitToRefreshTimer++;
    }
  }

  void updateKeepRefreshingTimer(bool isStable) {
    if (!isStable) {
      keepRefreshingTimer = 0;
    } else if (isRefreshing() &&
        keepRefreshingTimer <
            ARModeDebugValues.dynamicTimeToKeepRefreshing.value) {
      keepRefreshingTimer++;
    }
  }

  updateRefreshRate(bool isStable) {
    if (isStable &&
        isRefreshing() &&
        keepRefreshingTimer ==
            ARModeDebugValues.dynamicTimeToKeepRefreshing.value) {
      this.refreshData = ARModeDebugValues.dynamicStableRefreshTime.value;
      keepRefreshingTimer = 0;
      hasToRefresh = false;
    } else if (hasToRefresh &&
        waitToRefreshTimer == ARModeDebugValues.dynamicTimeToRefresh.value) {
      this.refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
      waitToRefreshTimer = 0;
      hasToRefresh = false;
    }
  }

  void forceResetRefreshTimers() {
    this.refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
    keepRefreshingTimer = 0;
    hasToRefresh = true;
  }

  bool _enoughARQuality(List<Location> locations) {
    if (locations.isEmpty) return false;
    avgLocAccuracy = 0;
    countNoHasBearings = 0;
    for (Location location in locations) {
      avgLocAccuracy += location.accuracy;
      if (!location.hasBearing) countNoHasBearings += 1;
    }
    avgLocAccuracy /= locations.length;
    return avgLocAccuracy < ARModeDebugValues.accuracyThreshold.value &&
        countNoHasBearings < ARModeDebugValues.noHasBearingThreshold.value;
  }

  bool _enoughARMovement(List<Location> locations) {
    double accumulatedDistance = 0.0;
    biggestJump = 0;

    for (var i = 0; i < locations.length - 1; i++) {
      double stepDistance = _euclideanDistance(locations[i], locations[i + 1]);
      biggestJump = max(stepDistance, biggestJump);
      if (stepDistance < ARModeDebugValues.jumpThreshold.value) {
        accumulatedDistance += stepDistance;
      }
    }

    distanceWalked = accumulatedDistance;
    if (accumulatedDistance < ARModeDebugValues.walkedThreshold.value) {
      return false;
    } else if (biggestJump > ARModeDebugValues.jumpThreshold.value) {
      return false;
    } else {
      return true;
    }
  }

  double _euclideanDistance(Location origin, Location destination) {
    var dx = pow(
        destination.cartesianCoordinate.x - origin.cartesianCoordinate.x, 2);
    var dy = pow(
        destination.cartesianCoordinate.y - origin.cartesianCoordinate.y, 2);
    return sqrt(dx + dy);
  }

  double angleDifference(double angle1, double angle2) {
    double difference = angle1 - angle2;
    if (difference > pi) {
      difference -= 2 * pi;
    } else if (difference < -pi) {
      difference += 2 * pi;
    }

    return difference;
  }

  double calculateAngleDifferencesStandardDeviation(List<Location> locations) {
    List<double> differences = [];

    for (int i = 1; i < locations.length; i++) {
      double angle1 = locations[i - 1].bearing?.radians ?? 0.0;
      double angle2 = locations[i].bearing?.radians ?? 0.0;
      differences.add(angleDifference(angle1, angle2));
    }
    // Ajuste para manejar diferencias alrededor de los límites de 0 y 2π
    differences = differences
        .map((diff) => diff.abs() > pi ? diff - (2 * pi * diff.sign) : diff)
        .toList();

    return calculateStandardDeviation(differences);
  }

  double calculateStandardDeviation(List<double> data) {
    if (data.isEmpty) {
      throw ArgumentError("Data list cannot be empty");
    }

    double mean =
        data.reduce((value, element) => value + element) / data.length;
    double variance = data
            .map((x) => pow(x - mean, 2))
            .reduce((value, element) => value + element) /
        data.length;

    return sqrt(variance);
  }

  bool allLocationsInSameFloor(List<Location> locations) {
    if (locations.isEmpty) {
      return false;
    }

    String firstFloor = locations[0].floorIdentifier;

    for (int i = 1; i < locations.length; i++) {
      if (locations[i].floorIdentifier != firstFloor) {
        return false;
      }
    }

    return true;
  }

  ARModeUnityParams getDynamicARParams() {
    return ARModeUnityParams(
        refreshData,
        ARModeDebugValues.navigationDistanceLimitData.value,
        ARModeDebugValues.navigationAngleLimitData.value,
        ARModeDebugValues.navigationAccuracyLimitDada.value,
        ARModeDebugValues.navigationCameraLimit.value);
  }
}
