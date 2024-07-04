part of 'ar.dart';

const LOCATION_BUFFER_SIZE = 15;
const DEFAULT_REFRESH_THRESHOLD = 0.2;

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
  RefreshThreshold currentRefreshThreshold =
      RefreshThreshold(DEFAULT_REFRESH_THRESHOLD, 0);
  RefreshThreshold lastRefreshThreshold = // last time and value of refresh
      RefreshThreshold(DEFAULT_REFRESH_THRESHOLD, 0);
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

    // Translate trajectory to origin
    LocationCoordinates origin = trajectory[0];
    List<LocationCoordinates> translatedTrajectory =
        trajectory.map((loc) => loc - origin).toList();

    if (translatedTrajectory.length == 1) return translatedTrajectory;

    // Search for minimum displacement
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
    }

    // Calculate rotation
    LocationCoordinates firstVector = translatedTrajectory[index];
    double angle = atan2(firstVector.y, firstVector.x);

    // Rotate
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
    currentRefreshThreshold.value = DEFAULT_REFRESH_THRESHOLD;
    currentRefreshThreshold.timestamp = currentTimestamp;
    ARModeDebugValues.dynamicRefreshThreshold.value =
        currentRefreshThreshold.value;
  }

  bool checkIfHasToRefreshAndUpdateThreshold(
      double conf, double arConf, double situmConf) {
    // conf threshold to force refresh
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (arConf < 0.8 || situmConf < 0.8) {
      resetThreshold();
      return true;
    } // if ar wrong, restart

    if (conf > currentRefreshThreshold.value + 0.2) {
      // only update if above 0.2 + its value
      // To state refresh and update refresh threshold
      currentRefreshThreshold.value = conf;
      currentRefreshThreshold.timestamp = currentTimestamp;
      ARModeDebugValues.dynamicRefreshThreshold.value =
          currentRefreshThreshold.value;
      return true;
    } else if ((conf < currentRefreshThreshold.value) &&
        currentTimestamp - currentRefreshThreshold.timestamp > 1000 &&
        currentRefreshThreshold.value > 0.20) {
      // if has passed more than n time, decrease threshold. TODO: Extract and adjust values, now, each 10s decrease 0.01.
      currentRefreshThreshold.value = currentRefreshThreshold.value - 0.01;
      currentRefreshThreshold.timestamp = currentTimestamp;
      ARModeDebugValues.dynamicRefreshThreshold.value =
          currentRefreshThreshold.value;
    }
    return false;
  }

  bool checkIfHasToRefreshForAndroid() {
    if (arLocations.isEmpty || sdkLocationCoordinates.isEmpty) {
      return true;
    }
    // check similarity

    var totalDisplacementSitum =
        computeTotalDisplacement(sdkLocationCoordinates, 20);

    var totalDisplacementAR = computeTotalDisplacement(arLocations, 20);
    var areOdoSimilar =
        estimateOdometriesMatch(arLocations, sdkLocationCoordinates);

    double arConf = estimateArConf();
    double situmConf = estimateSitumConf();
    double displacementConf = totalDisplacementConf(totalDisplacementSitum);
    double displacementConfAR = totalDisplacementConf(totalDisplacementAR);
    double odometriesDistanceConf =
        odometriesDifferenceConf(areOdoSimilar.distance);
    // double odometriesAngleDifferenceConf = _arPosQualityState!
    //     .odometriesAngleDifferenceConf(areOdoSimilar.angularDistance);
    double qualityMetric = arConf *
        situmConf *
        displacementConf *
        displacementConfAR *
        odometriesDistanceConf; //TODO: Angle conf

    // update debug info
    ARModeDebugValues.debugVariables.value = buildDebugMessage(
        ARModeDebugValues.refresh.value,
        areOdoSimilar,
        totalDisplacementSitum,
        totalDisplacementAR,
        arLocations.length,
        sdkLocationCoordinates.length,
        arConf,
        situmConf,
        ARModeDebugValues.dynamicRefreshThreshold.value,
        qualityMetric);

    // check if has to refresh
    return checkIfHasToRefreshAndUpdateThreshold(
        qualityMetric, arConf, situmConf);
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

  String buildDebugMessage(
      bool isRefreshing,
      areOdoSimilar,
      totalDisplacementSitum,
      totalDisplacementAR,
      arBufferSize,
      sdkBufferSize,
      arConf,
      situmConf,
      currentRefreshThreshold,
      qualityMetric) {
    String status = isRefreshing ? "REFRESHING" : "NOT REFRESHING";
    double angularDistanceDegrees = areOdoSimilar.angularDistance * 180 / pi;
    return "$status\n"
        "ar / Situm diff: ${areOdoSimilar.distance.toStringAsFixed(3)}  (${odometriesDifferenceConf(areOdoSimilar.distance).toStringAsFixed(3)})\n"
        "ar / situm angle diff: ${areOdoSimilar.angularDistance.toStringAsFixed(3)} , ${angularDistanceDegrees.toStringAsFixed(1)} , conf (${odometriesAngleDifferenceConf(areOdoSimilar.angularDistance).toStringAsFixed(3)})\n"
        "totalDisplacementSitum: ${totalDisplacementSitum.toStringAsFixed(3)}  (${totalDisplacementConf(totalDisplacementSitum!).toStringAsFixed(3)})\n"
        "totalDisplacementAR: ${totalDisplacementAR.toStringAsFixed(3)}\n"
        "ar buffer size: $arBufferSize\n"
        "sdk buffer size: $sdkBufferSize\n"
        "arCore Conf: $arConf\n"
        "situm Conf: $situmConf\n"
        "currentRefreshThreshold: ${currentRefreshThreshold.toStringAsFixed(3)}\n"
        "quality: ${qualityMetric.toStringAsFixed(3)}\n";
  }

  String buildDebugMessageForIOS(
      bool isRefreshing,
      areOdoSimilar,
      totalDisplacementSitum,
      totalDisplacementAR,
      arBufferSize,
      sdkBufferSize,
      arConf,
      situmConf,
      currentRefreshThreshold,
      qualityMetric) {
    String status = isRefreshing ? "REFRESHING" : "NOT REFRESHING";
    return "$status\n"
        "totalDisplacementSitum: ${totalDisplacementSitum.toStringAsFixed(3)}  (${totalDisplacementConf(totalDisplacementSitum!).toStringAsFixed(3)})\n"
        "ar buffer size: $arBufferSize\n"
        "sdk buffer size: $sdkBufferSize\n"
        "situm Conf: $situmConf\n"
        "currentRefreshThreshold: ${currentRefreshThreshold.toStringAsFixed(3)}\n"
        "quality: ${qualityMetric.toStringAsFixed(3)}\n";
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
