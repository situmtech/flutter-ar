import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:situm_flutter_ar/ar.dart';

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
