part of situm_flutter_ar;

// TODO: this file has been temporarily imported from a testing project. It needs review as it is a mess...

enum ARMode {
  relaxed,
  strict,
}

enum NavigationStatus { started, finished }

// POI selection callback.
typedef OnARModeChanged = void Function(ARMode arMode);

class ARModeManager {
  ARMode arMode = ARMode.relaxed;
  OnARModeChanged? onARModeChanged;

  ARModeManager(this.onARModeChanged);

  //Very simple algorith to calculate the AR Mode using only the NavigaitonStatus
  void updateARMode(NavigationStatus navigationStatus) {
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
}
