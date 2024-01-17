# situm_ar_example

Demonstrates how to use the situm_flutter_ar plugin.

## Getting Started

Copy `lib/config.dart.example` to `lib/config.dart` and populate the existent variables
according to your Situm account settings.

### Android:

> [!NOTE]  
> These steps are only for plugin developers.

1. Copy the `unityExport` folder to the folder `example/android/`.
2. Copy `example/bin/config.dart.example` to `example/bin/config.dart` and set the path to your
   local IL2CPP command.
3. Under `example/android/`, execute the following commands:
   ```shell
   flutter pub run situm_flutter_unity:unity_export_transmogrify
   flutter pub run bin/check_il2cpp
   ```