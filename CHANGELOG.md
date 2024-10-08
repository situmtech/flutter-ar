## 0.0.20 - September 27, 2024

### Changed:

- Updated Situm Flutter SDK to version 3.20.6. This version improves floor changes when positioning using BY_FOOT_VISUAL_ODOMETRY motion mode.

## 0.0.18 - September 10, 2024

### Changed:

- Updated Situm Flutter SDK to version 3.20.0. This version fixes a compatibility break and also a bug that displays a blank screen on the map under some circumstances.

## 0.0.17 - September 3, 2024

## Added:

- Added POI filtering to hide in the AR view POIs with the custom field ‘hidden-ar’ set to true.

## 0.0.16 - August 29, 2024

## Fixed:

- Fixed an issue where the viewer would remain in an inconsistent state on iOS devices after opening the AR view

## Changed:

- Added new algorithm to set coordinates to which the arrow is pointing during guidance and force this coordinates to be updated always.
- Increased default distance to point to coordinates to 25 m.
- Changed starting AR message from "AR Loading" to "Optimizing AR"
- Faster decrement of the quality metric threhsold to enforce a world reset. This reduces the time before a reset occurs which improves cases where the AR guidance is in an incorrect state.
- Updated flutter plugin version to 3.18.2

## 0.0.15 - August 14, 2024

### Changed:

- Improved integration with the Situm SDK: now this plugin actively closes the AR view when it
  receives a "USER_NOT_IN_BUILDING" location status.

### Removed:

- Removed a message that was confusing end users.

## 0.0.14 - July 16, 2024

- Fix. Check that the ar widget has been initialized before sending messages.

## 0.0.13 - July 04, 2024

- Integrated AR odometry into the positioning system to enhance accuracy.
- Enhanced the algorithm for deciding when to refresh the world, improving stability.
- A directional arrow is now displayed to indicate the route direction.

## 0.0.12 - May 21, 2024

- Added a new "AR Loading" UI widget.
- Updated the value of the position refresh parameter of the AR module.

## 0.0.11 - April 17, 2024

### Changed

- Updated the value of the position refresh parameter of the AR module.

## 0.0.10 - April 15, 2024

### Changed

- Updated Situm Flutter SDK to version 3.13.0.

### Fixed

- Fixed a bug where the plugin failed to load 3D ambiences when the AR module was not visible (and
  therefore paused).

## 0.0.9 - March 20, 2024

### Fixed

- Fixed a bug where the plugin failed to load 3D ambiences when the user was positioned in an
  area with multiple overlapping geofences, and the last notified geofence did not have AR metadata
  configured.

### Changed

- Updated Situm Flutter SDK to version 3.11.16.
- Updated camera distance limit to 20m.

### Removed

- Removed the "Low quality AR" message.

## 0.0.8 - March 14, 2024

### Added

- Added a new optional callback `onARVisibilityChanged` to get notified when the AR visibility
  changes.

## 0.0.7 - February 23, 2024

### Changed

- Updated the iOS configuration steps in the documentation to prevent UnityFramework from modifying
  the visibility of the system's status bar. As mentioned in the documentation, add the
  `UIViewControllerBasedStatusBarAppearance` key with a value of `false` to your Info.plist file:
  ```
   <key>UIViewControllerBasedStatusBarAppearance</key>
   <false/>
  ```
- Update `situm_flutter_unity` to version 0.0.3 to similarly prevent changes to the window mode on
  Android.
- Updated Situm Flutter SDK to
  version [3.11.13](https://situm.com/docs/flutter-sdk-changelog/#version-31113--february-23-2024).

### Fixed

- Fixed AR status mistakenly resumed (instead of paused) under some circumstances.

## 0.0.6 - February 20, 2024

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
