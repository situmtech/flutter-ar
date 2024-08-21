import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:situm_flutter_ar/ar.dart';

import 'ar.dart';

const distanceThresholdToFloorChange = 10;

double calculateDistance(
    Map<String, dynamic> point1, Map<String, dynamic> point2) {
  double x1 = point1['cartesianCoordinate']['x'];
  double y1 = point1['cartesianCoordinate']['y'];
  double x2 = point2['cartesianCoordinate']['x'];
  double y2 = point2['cartesianCoordinate']['y'];

  return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
}

Map<String, dynamic> projectPointOnSegment(
    Map<String, dynamic> P, Map<String, dynamic> A, Map<String, dynamic> B) {
  double x1 = A['cartesianCoordinate']['x'];
  double y1 = A['cartesianCoordinate']['y'];
  double x2 = B['cartesianCoordinate']['x'];
  double y2 = B['cartesianCoordinate']['y'];
  double x0 = P['cartesianCoordinate']['x'];
  double y0 = P['cartesianCoordinate']['y'];

  double dx = x2 - x1;
  double dy = y2 - y1;

  if (dx == 0 && dy == 0) {
    return A;
  }

  double t = ((x0 - x1) * dx + (y0 - y1) * dy) / (dx * dx + dy * dy);

  if (t < 0) {
    return A;
  } else if (t > 0) {
    return B;
  }

  return {
    'cartesianCoordinate': {
      'x': x1 + t * dx,
      'y': y1 + t * dy,
    }
  };
}

String findNextCoordinates(dynamic progress) {
  if (progress['segments'] == null ||
      progress['segments'][0] == null ||
      progress['segments'][0]['points'] == null) {
    debugPrint("findNextCoordinates: There are no segment points ");
    return "";
  }
  dynamic points = progress['segments'][0]['points']; //points in current floor
  List<Map<String, dynamic>> segments = List<Map<String, dynamic>>.from(points);
  Map<String, dynamic> currentPosition = progress['closestLocationInRoute']
      ['position']; //TODO: Check if that is correct

  // Initializing projectedPoint to a default value
  Map<String, dynamic> projectedPoint = segments[0];
  double minDistance = double.infinity;
  int segmentIndex = -1;

  for (int i = 0; i < segments.length - 1; i++) {
    Map<String, dynamic> A = segments[i];
    Map<String, dynamic> B = segments[i + 1];
    Map<String, dynamic> P = projectPointOnSegment(currentPosition, A, B);

    double distance = calculateDistance(currentPosition, P);
    if (distance < minDistance) {
      minDistance = distance;
      projectedPoint = P;
      segmentIndex = i;
    }
  }

  var totalDistance =
      calculateDistance(projectedPoint, segments[segmentIndex + 1]);
  var idx = 0;
  for (int i = segmentIndex + 1; i < segments.length - 1; i++) {
    idx = i;
    var distance = calculateDistance(segments[i], segments[i + 1]);
    totalDistance += distance;
    debugPrint(
        "${segments[i]["cartesianCoordinate"]["x"]} ${segments[i]["cartesianCoordinate"]["y"]} ${segments[i + 1]["cartesianCoordinate"]["x"]} ${segments[i + 1]["cartesianCoordinate"]["y"]} - ${distance} ${totalDistance}");
    if (totalDistance > ARModeDebugValues.arrowDistanceToSkipNode.value) break;
  }
  debugPrint(
      "$idx $totalDistance - ${segments[idx]["cartesianCoordinate"]["x"]} ${segments[idx]["cartesianCoordinate"]["y"]} ${segments[idx + 1]["cartesianCoordinate"]["x"]} ${segments[idx + 1]["cartesianCoordinate"]["y"]}  ");

  Map<String, dynamic> A = segments[idx]["cartesianCoordinate"];
  Map<String, dynamic> B = segments[idx + 1]["cartesianCoordinate"];
  double totalDistanceAB = calculateDistance(A, B);
  double distanceFromA = totalDistanceAB -
      (totalDistance - ARModeDebugValues.arrowDistanceToSkipNode.value);

// Calculate the ratio t for interpolation
  double t = distanceFromA / totalDistanceAB;

  debugPrint(A.toString());
  debugPrint(B.toString());

// Calculate the interpolated point
  double x = A["x"] + t * (B["x"] - A["x"]);
  double y = A["y"] + t * (B["y"] - A["y"]);

// Create the new point
  Map<String, double> interpolatedPoint = {
    "x": x,
    "y": y,
  };

  //return jsonEncode(interpolatedPoint);

  // debugPrint(jsonEncode(interpolatedPoint));
  //debugPrint(jsonEncode(segments[0]["cartesianCoordinate"]));

// Print the interpolated point
  debugPrint("New point at 10 meters away: x: $x, y: $y");

  for (int i = segmentIndex + 1; i < segments.length; i++) {
    double distance = calculateDistance(projectedPoint, segments[i]);
    if (distance > ARModeDebugValues.arrowDistanceToSkipNode.value) {
      return jsonEncode(segments[i]["cartesianCoordinate"]);
    } else if (i == segments.length - 1 && // last element
        progress['segments'].length > 1 && // there are more floors
        distance < distanceThresholdToFloorChange) {
      //below distance threshold
      return "floorChange";
    } else if (i == segments.length - 1) {
      return jsonEncode(segments[i]["cartesianCoordinate"]);
    }
  }

  return "";
}

bool getFloorChangeDirection(dynamic progressContent) {
  if (progressContent["currentIndication"]["distanceToNextLevel"] < 0) {
    return false;
  } else if (progressContent["currentIndication"]["distanceToNextLevel"] > 0) {
    return true;
  } else if (progressContent["nextIndication"]["distanceToNextLevel"] < 0) {
    return false;
  } else if (progressContent["nextIndication"]["distanceToNextLevel"] > 0) {
    return true;
  }
  return false;
}
