## Unreleased

### Added

- Now the plugin will display a `SnackBar` on 3D ambience changes, indicating that the user is
  entering or exiting 3D ambience zones.

### Changed

- Updated Situm Flutter SDK to
  version [3.11.9](https://situm.com/docs/flutter-sdk-changelog/#version-3119--february-16-2024).

### Fixed

- Fixed a bug that prevent the `MapView` to correctly follow user when the AR is displayed.

## 0.0.5 - February 09, 2024

### Changed

- The AR Widget now correctly handles `dispose()` calls occurring in "tabs" type implementations.

### Fixed

- Resolved a leak occurring in such situations.

## 0.0.4 - February 02, 2024

### Changed

- Now it is not necessary to forward SDK calls to the `ARController`. The AR module is notified
  internally about changes on location, navigation, geofencing (and so on).
- Updated Situm Flutter SDK dependency to version 3.11.4.

### Added

- Added a new parameter `enable3DAmbiences` to recreate ambiences in the augmented reality view with
  animations and 3D objects. The activation of each environment is based on the entry/exit on
  Geofences, which must be configured in the dashboard through the "ar_metadata" custom field.
  Example:
   ```
    ar_metadata: {"ambience": "ambience_name"}
  ```
  To enable 3D ambiences for your venue, contact [Situm support](mailto:support@situm.com).

- Added new parameters `occlusionAndroid`, `occlusionIOS` to enable or disable 3D model occlusion.

## 0.0.3 - January 26, 2024

- Improved MapView integration by introducing a combined AR-MapView view.
    - The combined view automatically centers the user position and disables user events for the
      map.
    - A new button completely hides the MapView for a full screen AR experience.
- Enhanced the plugin to exit the AR view when navigation concludes, accommodating cancellations or
  reaching the destination.

## 0.0.2 - January 19, 2024

- Fix Android setup in the README.

## 0.0.1 - January 19, 2024

- Initial version of the Flutter AR plugin.
