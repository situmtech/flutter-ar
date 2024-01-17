# Situm Flutter AR

<p align="center"> <img width="233" src="https://situm.com/wp-content/themes/situm/img/logo-situm.svg" style="margin-bottom:1rem" />
<h1 align="center">@situm/flutter</h1>
</p>

<p align="center" style="text-align:center">

Bring AR to [Situm Wayfinding](https://situm.com/wayfinding).

</p>

<div align="center" style="text-align:center">

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Pub Version](https://img.shields.io/pub/v/situm_flutter?color=blueviolet)](https://pub.dev/packages/situm_flutter)
[![Flutter](https://img.shields.io/badge/{/}-flutter-blueviolet)](https://flutter.dev/)

</div>

## Getting Started

Checkout the [example app](./example) of this repository to get started with the AR module.

> [!NOTE]  
> This plugin is a work in progress.

### Android and iOS setup:

#### Set up your Situm credentials:

First, go to `example/lib` and copy the file `config.dart.example` to a new file
called `config.dart`.
Then populate the new file with your Situm credentials.
Follow the [Wayfinding guide](https://situm.com/docs/first-steps-for-wayfinding/) if you haven't set
up a Situm account.

#### Install the plugin:

For the example app of this repository:

1. Run `flutter pub get` under the `exemple/` directory.

In case of a clean installation:

1. Install [situm_flutter_ar](TODO link)
   and [situm_flutter_unity](https://pub.dev/packages/situm_flutter_unity):
    ```shell
    flutter pub add situm_flutter_ar
    flutter pub add situm_flutter_unity
    ```
2. Follow configuration steps for tye integration with Unity (for both iOS and Android)
   at https://pub.dev/packages/situm_flutter_unity#configuring-your-flutter-project.

### iOS specific steps:

The steps bellow are **required** even for the example app of this repository:

1. Download and extract the AR binaries (UnityFramework.xcframework) from Situm (TODO: link).
2. Open xcode and drag the UnityFramework to your project, make sure you have selected the following
   options:
    - Check copy items if needed.
    - Select "Create groups" for "Added folders".
    - Add to target "Runner".
3. In the main Target of your app, under General > "Frameworks, Libraries and Embedded Content",
   select "Embed & Sign" for the UnityFramework.xcframework.
4. Under `example/ios/`, run `pod install`.
5. Run your app.

### Android specific steps:

Steps already completed in the sample app of this repository:

1. You may need to add the following line to your `settings.gradle` file:
   ```groovy
    include ':unityExport:xrmanifest.androidlib'
   ```
2. Add this line to your `gradle.properties` file:
   ```properties
    unityStreamingAssets=.unity3d, google-services-desktop.json, google-services.json, GoogleService-Info.plist
   ```

The steps bellow are **required** even for the example app of this repository:

1. Download and extract the AR binaries from Situm (TODO: link).
2. Populate the following directories (TODO: automatize):
    - example/android/unityExport/libs/
    - example/android/unityExport/src/
    - example/android/unityExport/symbols/
3. Run your app.

Only for plugin development:

1. Install Android NDK version `23.1.7779620` and CMAKE (if necessary).
2. You probably will need to install
   the [IL2CPP command tool](https://unity.com/releases/editor/qa/lts-releases?major_version=&minor_version=&version=&page=0)
   adapted to your development environment.

## Versioning

Please refer to [CHANGELOG.md](TODO link) for a list of notable changes for each version of the
plugin.

You can also see the [tags on this repository](./tags).

---

## Submitting contributions

You will need to sign a Contributor License Agreement (CLA) before making a
submission. [Learn more here](https://situm.com/contributions/).

---

## License

This project is licensed under the MIT - see the [LICENSE](./LICENSE) file for further details.

---

## More information

More info is available at our [Developers Page](https://situm.com/docs/01-introduction/).

---

## Support information

For any question or bug report, please send an email
to [support@situm.com](mailto:support@situm.com)