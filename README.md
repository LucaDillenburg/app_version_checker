# App Version Checker - Plugin 🎉

A Flutter plugin that makes it possible to: 
* Check if a user has the most recent version of your app installed.
* Show the user an alert with a link to the appropriate app store page.

<!-- See more at the [Dart Packages page.](https://pub.dartlang.org/packages/new_version) -->

![Screenshots](screenshots/both.png)

## Installation
Add new_version as [a dependency in your `pubspec.yaml` file.](https://flutter.io/using-packages/)
```
dependencies:
  app_version_checker: [latest_version]
```

## Usage
In `main.dart` (or wherever your app is initialized), create an instance of `NewVersion`.

`final appVersionChecker = AppVersionChecker();`

The plugin will automatically use your Flutter package identifier to check the app store. If your app has a different identifier in the Google Play Store or Apple App Store, you can overwrite this by providing values for `androidId` and/or `iOSId`.

*For iOS:* If your app is only available outside the U.S. App Store, you will need to set `iOSAppStoreCountry` to the two-letter country code of the store you want to search. See http://en.wikipedia.org/wiki/ISO_3166-1_alpha-2 for a list of ISO Country Codes.

You can then use the plugin in two ways.

### Quickstart
```
final status = await appVersionChecker.getVersionStatus();
status.canUpdate // (true)
status.localVersion // (1.2.1)
status.storeVersion // (1.2.3)
status.appStoreLink // (https://itunes.apple.com/us/app/google/id284815942?mt=8)

appVersionChecker.launchAppStore(status.appStoreLink);
```
