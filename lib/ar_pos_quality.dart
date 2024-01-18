part of 'ar.dart';

const LOCATION_BUFFER_SIZE = 10;

class _ARPosQuality extends StatefulWidget {
  final Function(_ARPosQualityState) onCreate;

  const _ARPosQuality({
    Key? key,
    required this.onCreate,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    widget.onCreate.call(this);
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: showARAlertWidget,
      child: const Align(
        alignment: Alignment.bottomCenter,
        child: IntrinsicHeight(
          child: Card(
            elevation: 4.0,
            margin: EdgeInsets.all(16.0),
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
        ----
        AvgLocAccuracy: ${avgLocAccuracy.toStringAsFixed(1)} Th: ${ARModeDebugValues.accuracyThreshold.value.toStringAsFixed(1)}
        NoHasBearings: $countNoHasBearings Th: ${ARModeDebugValues.noHasBearingThreshold.value}
        Walked: ${distanceWalked.toStringAsFixed(1)} Th: ${ARModeDebugValues.walkedThreshold.value.toStringAsFixed(1)}
        MaxJump: ${biggestJump.toStringAsFixed(1)} Th: ${ARModeDebugValues.jumpThreshold.value.toStringAsFixed(1)}
        ---
        Converged (good loc acc & hasBearing): $converged
        HasWalked (walked & no jumps): $hasWalked
        UserNeedsToWalk (hasWalked & still converged): $userNeedsToWalk
        ---
        GoodARQuality (converged & !userNeedsToWalk): $goodARQuality
        """;
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
}
