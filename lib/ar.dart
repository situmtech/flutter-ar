library situm_flutter_ar;

import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:situm_flutter/sdk.dart';
import 'package:situm_flutter/wayfinding.dart';
import 'package:situm_flutter_unity/flutter_unity.dart';

import 'route_utils.dart';

part 'ar_debug.dart';

part 'ar_mode.dart';

part 'ar_pos_quality.dart';

part 'situm_ar.dart';

part 'ar_controller.dart';

part 'ar_definitions.dart';

part 'utils.dart';

const _keyArMetadata = "ar_metadata";
const _keyArMetadataAmbience = "ambience";

const _ambiences3DCodes = {
  'no_ambience': 0,
  'desert': 1,
  'oasis': 2,
  'city': 3,
  'sea': 4,
};
