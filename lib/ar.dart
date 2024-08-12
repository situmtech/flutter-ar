library situm_flutter_ar;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:situm_flutter/sdk.dart';
import 'package:situm_flutter/wayfinding.dart';

part 'ar_controller.dart';

part 'ar_definitions.dart';

part 'ar_view.dart';

part 'situm_ar.dart';

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
