## Unreleased

### Changed

- Now it is not necessary to forward SDK calls to the `ARController`. The AR module is notified
  internally about changes on location, navigation, geofencing (and so on).

### Added

- Added a new parameter `enable3DAmbiences` to recreate ambiences in the augmented reality view with
  animations and 3D objects. The activation of each environment is based on the entry/exit on
  Geofences, which must be configured in the dashboard through the "ar_metadata" custom field.
  Example:
   ```
    ar_metadata: {"ambience": "oasis"}
  ```
- Added new parameters `occlusionAndroid`, `occlusionIOS` to enable or disable 3D model occlusion.