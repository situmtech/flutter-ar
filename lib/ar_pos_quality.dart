part of 'ar.dart';

const LOCATION_BUFFER_SIZE = 30;
const DEFAUL_REFRESH_THRESHOLD = 0.2;

class _ARPosQuality extends StatefulWidget {
  final Function(_ARPosQualityState) onCreate;

  const _ARPosQuality({
    super.key,
    required this.onCreate,
  });

  @override
  _ARPosQualityState createState() => _ARPosQualityState();
}

class RefreshThreshold {
  double value;
  int timestamp;

  RefreshThreshold(this.value, this.timestamp);

  @override
  String toString() {
    return 'RefreshTrehsold(value: $value, timestamp:$timestamp)';
  }
}

double normalizeAngle(double angle) {
  while (angle <= -pi) {
    angle += 2 * pi;
  }
  while (angle > pi) {
    angle -= 2 * pi;
  }
  return angle;
}

class LocationCoordinates {
  final double x;
  final double y;
  double yaw;
  final int timestamp;

  LocationCoordinates(this.x, this.y, this.yaw, this.timestamp);

  LocationCoordinates operator -(LocationCoordinates other) =>
      LocationCoordinates(x - other.x, y - other.y, yawAdd(-other.yaw),
          timestamp - other.timestamp);

  double distanceTo(LocationCoordinates other) {
    return sqrt((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y));
  }

  LocationCoordinates rotate(double angle) {
    double cosA = cos(angle);
    double sinA = sin(angle);
    return LocationCoordinates(
        x * cosA - y * sinA, x * sinA + y * cosA, yawAdd(angle), timestamp);
  }

  double angularDistanceTo(LocationCoordinates other) {
    double angleDifference = yaw - other.yaw;
    angleDifference = normalizeAngle(angleDifference);
    return angleDifference.abs();
  }

  double yawAdd(double angle) {
    double sum = yaw + angle;
    sum = normalizeAngle(sum);
    return sum;
  }

  @override
  String toString() {
    return 'LocationCoordinates(x: $x, y: $y, yaw: $yaw, timestamp: $timestamp)';
  }
}

class OdometriesMatchResult {
  final double distance;
  final double angularDistance;

  OdometriesMatchResult(this.distance, this.angularDistance);

  @override
  String toString() {
    return 'OdometriesMatchResult(distance: $distance, angularDistance: $angularDistance)';
  }
}

class _ARPosQualityState extends State<_ARPosQuality> {
  double avgLocAccuracy = -1.0;
  double distanceWalked = -1.0;
  double biggestJump = -1.0;
  int countNoHasBearings = 0;
  bool hasBearing = false;
  int debugModeCount = 0;

  List<Location> sdkLocations = [];
  List<LocationCoordinates> sdkLocationCoordinates = [];
  List<LocationCoordinates> arLocations = [];
  bool userNeedsToWalk = true;

  bool showARAlertWidget = true;

  int refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
  bool hasToRefresh = true;
  int waitToRefreshTimer = 0;
  int keepRefreshingTimer = 0;
  double yawDiffStd = 0;

  LocationCoordinates lastArLocation = LocationCoordinates(0, 0, 0, 0);
  RefreshThreshold refreshThreshold =
      RefreshThreshold(DEFAUL_REFRESH_THRESHOLD, 0);

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

  Location createLocationFromARMessage(String message) {
    var jsonData = jsonDecode(message);
    return Location(
      coordinate: Coordinate(
        latitude: 0,
        longitude: 0,
      ),
      cartesianCoordinate: CartesianCoordinate(
        x: jsonData["position"]["x"] ?? 0,
        y: jsonData["position"]["z"] ?? 0,
      ),
      bearing: Angle(
        // TODO: conversions
        degrees: jsonData["eulerRotation"]["y"],
        degreesClockwise: jsonData["eulerRotation"]["y"],
        radians: 0,
        radiansMinusPiPi: 0,
      ),
      accuracy: 0,
      buildingIdentifier: '',
      floorIdentifier: '',
      hasBearing: true,
      isIndoor: true,
      isOutdoor: false,
      timestamp: jsonData["timestamp"].toInt(),
    );
  }

  LocationCoordinates createLocationCoordinatesFromARMessage(String message) {
    var jsonData = jsonDecode(message);
    return LocationCoordinates(
      jsonData["position"]["x"] ?? 0,
      jsonData["position"]["z"] ?? 0,
      (jsonData["eulerRotation"]["y"] * pi / 180) ?? 0,
      jsonData["timestamp"].toInt(),
    );
  }

  void clearBuffers() {
    sdkLocations.clear();
    sdkLocationCoordinates.clear();
    arLocations.clear();
  }

  void updateArLocation(String message) {
    lastArLocation = createLocationCoordinatesFromARMessage(message);
    lastArLocation.yaw = lastArLocation.yaw - (pi / 2);
  }

  void updateArLocationBuffer() {
    arLocations.add(lastArLocation); // parse message to location
    if (arLocations.length > LOCATION_BUFFER_SIZE) {
      arLocations.removeAt(0);
    }
  }

  void updateSdkLocationBuffer(Location location) {
    sdkLocations.add(location);
    sdkLocationCoordinates.add(LocationCoordinates(
        location.cartesianCoordinate.x,
        location.cartesianCoordinate.y,
        location.bearing!.radians,
        location.timestamp));

    if (sdkLocations.length > LOCATION_BUFFER_SIZE) {
      sdkLocations.removeAt(0);
    }
    if (sdkLocationCoordinates.length > LOCATION_BUFFER_SIZE) {
      sdkLocationCoordinates.removeAt(0);
    }
  }

  void updateLocation(Location location) {
    if (sdkLocations.isNotEmpty &&
        location.floorIdentifier != sdkLocations.last.floorIdentifier) {
      clearBuffers();
      resetThreshold();
    }
    updateArLocationBuffer();
    updateSdkLocationBuffer(location);
  }

  double estimateArConf() {
    const int requiredPositions = 10;
    const double maxConfidence = 1.0;
    int numOkPositions = 0;

    // check last 10 positions
    double confidence = maxConfidence;
    for (int i = arLocations.length - 1;
        i >= max(arLocations.length - requiredPositions, 0);
        i--) {
      // If no ar it freezes, we receive the last value again.
      if (arLocations[i].x == 0 && arLocations[i].y == 0 ||
          i < 1 ||
          arLocations[i].y == arLocations[i - 1].y &&
              arLocations[i].x == arLocations[i - 1].x) {
        break;
      } else {
        numOkPositions++;
      }
    }
    confidence = (numOkPositions / requiredPositions) * maxConfidence;
    return confidence;
  }

  double estimateSitumConf() {
    const int requiredPositions = 10;
    const double maxConfidence = 1.0;

    int numOkPositions = 0;
    double confidence = maxConfidence;

    for (int i = sdkLocations.length - 1;
        i >= max(sdkLocations.length - requiredPositions, 0);
        i--) {
      if (sdkLocations[i].accuracy > 5 &&
              !sdkLocations[i].hasBearing || //has bearing works?
          i < 0) {
        break;
      } else {
        numOkPositions++;
      }
    }

    confidence = (numOkPositions / requiredPositions) * maxConfidence;
    return confidence;
  }

///////////////////////////////////////////

// from defines last n positions. if 0, is from origin
  double computeAccumulatedDisplacement(
      List<LocationCoordinates> coordinates, int from) {
    if (coordinates.length < 2) return 0.0;

    double totalDisplacement = 0.0;
    int i = 0;
    if (from != 0) {
      i = max(coordinates.length - from, 0);
    }
    for (i; i < coordinates.length - 1; i++) {
      totalDisplacement += coordinates[i].distanceTo(coordinates[i + 1]);
    }

    return totalDisplacement;
  }

// from defines last n positions. if 0, is from origin
  double computeTotalDisplacement(
      List<LocationCoordinates> coordinates, int from) {
    if (coordinates.length < 2) return 0.0;

    double totalDisplacement = 0.0;
    if (from == 0) {
      totalDisplacement = coordinates.first.distanceTo(coordinates.last);
    } else {
      int fromIndex = max(coordinates.length - from, 0);
      totalDisplacement = coordinates[fromIndex].distanceTo(coordinates.last);
    }

    return totalDisplacement;
  }

  List<LocationCoordinates> transformTrajectory(
      List<LocationCoordinates> trajectory) {
    if (trajectory.isEmpty) return [];

    // Trasladar la trayectoria para que comience en el origen
    LocationCoordinates origin = trajectory[0];
    List<LocationCoordinates> translatedTrajectory =
        trajectory.map((loc) => loc - origin).toList();

    if (translatedTrajectory.length == 1) return translatedTrajectory;

    // Buscar un vector con desplazamiento mayor a 2 metros
    double distance = 0;
    int index = 1;
    while (index < translatedTrajectory.length) {
      distance =
          translatedTrajectory[0].distanceTo(translatedTrajectory[index]);
      if (distance > 2) break;
      index++;
    }
    if (index >= translatedTrajectory.length) {
      return translatedTrajectory;
    } // No se encontró un vector con desplazamiento suficiente}

    // Calcular el ángulo de rotación necesario
    LocationCoordinates firstVector = translatedTrajectory[index];
    double angle = atan2(firstVector.y, firstVector.x);
    //debugPrint("rotate substract angle ${angle}");
    // Rotar la trayectoria para alinear con el eje x
    List<LocationCoordinates> alignedTrajectory =
        translatedTrajectory.map((loc) => loc.rotate(-angle)).toList();

    return alignedTrajectory;
  }

// Align at same origin and estimate distance between last positions
  OdometriesMatchResult estimateOdometriesMatch(
      List<LocationCoordinates> arLocations,
      List<LocationCoordinates> sdkLocations) {
    // Transformar ambas trayectorias
    List<LocationCoordinates> transformedARLocations =
        transformTrajectory(arLocations);
    List<LocationCoordinates> transformedSDKLocations =
        transformTrajectory(sdkLocations);

    var distance =
        transformedARLocations.last.distanceTo(transformedSDKLocations.last);
    var angularDistance = transformedARLocations.last
        .angularDistanceTo(transformedSDKLocations.last);
    // debugPrint(
    //     "arlocation _ original: ${arLocations.last.toString()} , sdklocation original: ${sdkLocations.last.toString()}");
    // debugPrint(
    //     "arlocation _ first: ${arLocations.first.toString()} , sdklocation original: ${sdkLocations.first.toString()}");
    // debugPrint(
    //     "arlocation: ${transformedARLocations.last.toString()} , sdklocation: ${transformedSDKLocations.last.toString()}");

    // String arLocationsString = arLocations
    //     .map((loc) => '>>,${loc.x}, ${loc.y}, ${loc.yaw}')
    //     .join('\n ');
    // String arLocationsTransformedString = transformedARLocations
    //     .map((loc) => '>>,${loc.x}, ${loc.y}, ${loc.yaw}')
    //     .join('\n ');
    // String sdkLocationsString = sdkLocations
    //     .map((loc) => '>>,${loc.x}, ${loc.y}, ${loc.yaw}')
    //     .join('\n ');
    // String sdkLocationsTransformedString = transformedSDKLocations
    //     .map((loc) => '>>,${loc.x}, ${loc.y}, ${loc.yaw}')
    //     .join('\n ');
    // debugPrint(">>-------------------------------------");
    // debugPrint(">>AR LOCATIONS\n, $arLocationsString");
    // debugPrint(">>AR LOCATIONS TRansformed\n, $arLocationsTransformedString");
    // debugPrint(">>Situm Locations\n, $sdkLocationsString");
    // debugPrint(
    //     ">>Situm Locations Transformed\n, $sdkLocationsTransformedString");
    // debugPrint(">>-------------------------------------");
    return OdometriesMatchResult(distance, angularDistance);
  }

  double odometriesDifferenceConf(double difference) {
    const diffThreshold = 10;
    if (difference > diffThreshold) {
      return 0;
    }
    return (1 - difference / diffThreshold);
  }

  double odometriesAngleDifferenceConf(double difference) {
    const diffThreshold = 0.30;
    if (difference > diffThreshold) {
      return 0;
    }
    return (1 - difference / diffThreshold);
  }

  double totalDisplacementConf(double distance) {
    const minDistanceThreshold = 10;
    if (distance > minDistanceThreshold) {
      return 1;
    }
    return (distance / minDistanceThreshold);
  }

  void resetThreshold() {
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    refreshThreshold.value = DEFAUL_REFRESH_THRESHOLD;
    refreshThreshold.timestamp = currentTimestamp;
    ARModeDebugValues.dynamicRefreshThreshold.value = refreshThreshold.value;
  }

  bool checkIfHasToRefreshAndUpdateThreshold(
      double conf, double arConf, double situmConf) {
    // conf threshold to force refresh
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (arConf < 0.8 || situmConf < 0.8) {
      resetThreshold();
      return true;
    } // if ar wrong, restart
    if (conf > refreshThreshold.value) {
      // To state refresh and update refresh threshold
      refreshThreshold.value = conf;
      refreshThreshold.timestamp = currentTimestamp;
      ARModeDebugValues.dynamicRefreshThreshold.value = refreshThreshold.value;
      return true;
    } else if (currentTimestamp - refreshThreshold.timestamp > 1000 &&
        refreshThreshold.value > 0.20) {
      // if has passed more than n time, decrease threshld. TODO: Extract and adjust values, now, each 10s decrease 0.01.
      refreshThreshold.value = refreshThreshold.value - 0.01;
      refreshThreshold.timestamp = currentTimestamp;
      ARModeDebugValues.dynamicRefreshThreshold.value = refreshThreshold.value;
    }
    return false;
  }

  // void updateLocation(Location location) {
  //   sdkLocations.add(location);
  //   if (sdkLocations.length > LOCATION_BUFFER_SIZE) {
  //     sdkLocations.removeAt(0);
  //   }

  //   var converged = false;
  //   var hasWalked = false;

  //   if (sdkLocations.length == LOCATION_BUFFER_SIZE) {
  //     converged = _enoughARQuality(sdkLocations);
  //     hasWalked = _enoughARMovement(sdkLocations);
  //   }

  //   updateDynamicARParams(sdkLocations);

  //   if (!converged) {
  //     userNeedsToWalk = true;
  //   }

  //   var goodARQuality = converged;

  //   if (userNeedsToWalk) {
  //     goodARQuality = converged && hasWalked;
  //     if (goodARQuality) {
  //       // No need to walk if converged and already walked
  //       userNeedsToWalk = false;
  //     }
  //   }

  //   setState(() {
  //     showARAlertWidget = !goodARQuality;
  //   });

  //   var locationMap = location.toMap();
  //   locationMap["timestamp"] = -1;

  //   ARModeDebugValues.debugVariables.value = """
  //       Locations Number: ${sdkLocations.length}
  //       Walked: ${distanceWalked.toStringAsFixed(1)} Th: ${ARModeDebugValues.walkedThreshold.value.toStringAsFixed(1)}
  //       ----
  //       yawDiffStd: $yawDiffStd,
  //       Dynamic params:
  //        refreshData: $refreshData,
  //        distanceLimitData: ${ARModeDebugValues.navigationDistanceLimitData.value},
  //        hasToRefresh: $hasToRefresh,
  //        waitToRefreshTimer: $waitToRefreshTimer,
  //        keepRefreshingTimer: $keepRefreshingTimer,
  //       ---
  //       accuracyLimitData: ${ARModeDebugValues.navigationAccuracyLimitDada.value}
  //       ---
  //       converged: $converged
  //       hasWalked: $hasWalked
  //       goodARQuality: $goodARQuality
  //       """;
  // }

  void updateDynamicARParams(List<Location> locations) {
    if (locations.length < ARModeDebugValues.locationBufferSize.value ||
        !allLocationsInSameFloor(locations)) {
      refreshData = ARModeDebugValues.dynamicUnstableRefreshTime.value;
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
