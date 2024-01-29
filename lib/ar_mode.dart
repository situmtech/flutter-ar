part of 'ar.dart';

// TODO: this file has been temporarily imported from a testing project. It needs review as it is a mess...

enum ARMode { enjoy, relaxed, strict, dynamic }

ARMode DEFAULT_AR_MODE = ARMode.dynamic;

enum NavigationStatus { started, finished }

// POI selection callback.
typedef OnARModeChanged = void Function(ARMode arMode);

class ARModeManager {
  ARMode arMode = DEFAULT_AR_MODE;
  ARMode? previousARMode;
  OnARModeChanged? onARModeChanged;

  ARModeManager(this.onARModeChanged);

  // Very simple algorithm to calculate the AR Mode using only the NavigationStatus
  void updateWithNavigationStatus(NavigationStatus navigationStatus) {
    if (arMode == ARMode.dynamic) {
      return;
    }
    previousARMode = arMode;
    switch (navigationStatus) {
      case NavigationStatus.started:
        if (arMode != ARMode.strict) {
          arMode = ARMode.strict;
          onARModeChanged?.call(arMode);
        }

      case NavigationStatus.finished:
        if (arMode != ARMode.relaxed) {
          arMode = ARMode.relaxed;
          onARModeChanged?.call(arMode);
        }
    }
  }

  void setARMode(ARMode mode) {
    previousARMode = arMode;
    arMode = mode;
    onARModeChanged?.call(arMode);
  }

  void switchToPreviousMode() {
    if (previousARMode != null) {
      arMode = previousARMode!;
      onARModeChanged?.call(arMode);
    }
  }
}
