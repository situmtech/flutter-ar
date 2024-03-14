part of 'ar.dart';

enum ARVisibility {
  /// The AR module has been requested and is visible.
  visible,

  /// The AR module is not visible.
  gone,
}

class ARMetadata {
  late final String? ambience;

  int get ambienceCode {
    return _ambiences3DCodes[ambience] ?? 0;
  }

  static ARMetadata? _fromCustomFields(Map<String, dynamic>? customFields) {
    String? rawData = customFields?[_keyArMetadata];
    if (rawData == null) {
      return null;
    }
    ARMetadata arMetadata = ARMetadata();
    var decodedData = jsonDecode(rawData);
    arMetadata.ambience = decodedData?[_keyArMetadataAmbience];
    return arMetadata;
  }

  static ARMetadata? _fromGeofence(Geofence geofence) {
    return ARMetadata._fromCustomFields(geofence.customFields);
  }

  /// Return the first ar_metadata found in the given list of Geofences.
  /// This may change (e.g. priorities) but the dependency with List<Geofence>
  /// should be kept.
  static ARMetadata? _fromGeofences(List<Geofence> geofences) {
    for (Geofence geofence in geofences) {
      ARMetadata? arMetadata = ARMetadata._fromGeofence(geofence);
      if (arMetadata != null) {
        return arMetadata;
      }
    }
    return null;
  }
}

class _Validations {
  String validateApiDomain(String apiDomain) {
    if (!apiDomain.startsWith('http://') && !apiDomain.startsWith('https://')) {
      apiDomain = 'https://$apiDomain';
    }
    Uri? uri = Uri.tryParse(apiDomain);
    if (uri == null || !uri.isAbsolute) {
      throw ArgumentError(
          'Incorrect configuration: apiDomain ($apiDomain) must be a valid URL.');
    }
    if (apiDomain.endsWith("/")) {
      apiDomain = apiDomain.substring(0, apiDomain.length - 1);
    }
    return apiDomain;
  }
}
