library app_version_checker;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class Version {
  late final int major;
  late final int minor;
  late final int patch;
  Version(this.major, this.minor, this.patch);
  Version.fromString(String version) {
    final versionComponents = version.split('.');
    major = int.parse(versionComponents[0]);
    minor = int.parse(versionComponents[1]);
    patch = int.parse(versionComponents[2]);
  }
  String toVersionString() => '`$major.$minor.$patch`';
  List<int> get props => [major, minor, patch];
}

/// Information about the app's current version, and the most recent version
/// available in the Apple App Store or Google Play Store.
class AppVersions {
  /// The current version of the app.
  final Version localVersion;

  /// The most recent version of the app in the store.
  final Version storeVersion;

  /// A link to the app store page where the app can be updated.
  final String appStoreLink;

  /// The release notes for the store version of the app.
  final String? releaseNotes;

  /// Returns `true` if the store version of the application is greater than the local version.
  bool get canUpdate {
    final local = localVersion.props;
    final store = storeVersion.props;

    // Each consecutive field in the version notation is less significant than the previous one,
    // therefore only one comparison needs to yield `true` for it to be determined that the store
    // version is greater than the local version.
    for (var i = 0; i < store.length; i++) {
      // The store version field is newer than the local version.
      if (store[i] > local[i]) {
        return true;
      }

      // The local version field is newer than the store version.
      if (local[i] > store[i]) {
        return false;
      }
    }

    // The local and store versions are the same.
    return false;
  }

  AppVersions._({
    required this.localVersion,
    required this.storeVersion,
    required this.appStoreLink,
    this.releaseNotes,
  });
}

class AppVersionChecker {
  /// An optional value that can override the default packageName when
  /// attempting to reach the Apple App Store. This is useful if your app has
  /// a different package name in the App Store.
  final String? iOSId;

  /// An optional value that can override the default packageName when
  /// attempting to reach the Google Play Store. This is useful if your app has
  /// a different package name in the Play Store.
  final String? androidId;

  /// Only affects iOS App Store lookup: The two-letter country code for the store you want to search.
  /// Provide a value here if your app is only available outside the US.
  /// For example: US. The default is US.
  /// See http://en.wikipedia.org/wiki/ ISO_3166-1_alpha-2 for a list of ISO Country Codes.
  final String? iOSAppStoreCountry;

  /// An optional value that will force the plugin to always return [forceAppVersion]
  /// as the value of [storeVersion]. This can be useful to test the plugin's behavior
  /// before publishng a new version.
  final String? forceAppVersion;

  AppVersionChecker({
    this.androidId,
    this.iOSId,
    this.iOSAppStoreCountry,
    this.forceAppVersion,
  });

  /// This checks the version status and returns the information. This is useful
  /// if you want to display a custom alert, or use the information in a different
  /// way.
  Future<AppVersions?> getVersionStatus() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    if (Platform.isIOS) {
      return _getiOSStoreVersion(packageInfo);
    } else if (Platform.isAndroid) {
      return _getAndroidStoreVersion(packageInfo);
    } else {
      debugPrint('The target platform "${Platform.operatingSystem}" is not yet supported by this package.');
      return null;
    }
  }

  /// This function attempts to clean local version strings so they match the MAJOR.MINOR.PATCH
  /// versioning pattern, so they can be properly compared with the store version.
  String _getCleanVersion(String version) => RegExp(r'\d+\.\d+\.\d+').stringMatch(version) ?? '0.0.0';

  /// iOS info is fetched by using the iTunes lookup API, which returns a
  /// JSON document.
  Future<AppVersions?> _getiOSStoreVersion(PackageInfo packageInfo) async {
    final id = iOSId ?? packageInfo.packageName;
    final parameters = {"bundleId": "$id"};
    if (iOSAppStoreCountry != null) {
      parameters.addAll({"country": iOSAppStoreCountry!});
    }
    var uri = Uri.https("itunes.apple.com", "/lookup", parameters);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Failed to query iOS App Store');
      return null;
    }
    final jsonObj = json.decode(response.body);
    final List results = jsonObj['results'];
    if (results.isEmpty) {
      debugPrint('Can\'t find an app in the App Store with the id: $id');
      return null;
    }
    return AppVersions._(
      localVersion: Version.fromString(_getCleanVersion(packageInfo.version)),
      storeVersion: Version.fromString(_getCleanVersion(forceAppVersion ?? jsonObj['results'][0]['version'])),
      appStoreLink: jsonObj['results'][0]['trackViewUrl'],
      releaseNotes: jsonObj['results'][0]['releaseNotes'],
    );
  }

  /// Android info is fetched by parsing the html of the app store page.
  Future<AppVersions?> _getAndroidStoreVersion(PackageInfo packageInfo) async {
    final id = androidId ?? packageInfo.packageName;
    final uri = Uri.https("play.google.com", "/store/apps/details", {"id": "$id", "hl": "en"});
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      debugPrint('Can\'t find an app in the Play Store with the id: $id');
      return null;
    }
    final document = parse(response.body);

    String storeVersion = '0.0.0';
    String? releaseNotes;

    final additionalInfoElements = document.getElementsByClassName('hAyfc');
    if (additionalInfoElements.isNotEmpty) {
      final versionElement = additionalInfoElements.firstWhere(
        (elm) => elm.querySelector('.BgcNfc')!.text == 'Current Version',
      );
      storeVersion = versionElement.querySelector('.htlgb')!.text;

      final sectionElements = document.getElementsByClassName('W4P4ne');
      final releaseNotesElement = sectionElements.firstWhereOrNull(
        (elm) => elm.querySelector('.wSaTQd')!.text == 'What\'s New',
      );
      releaseNotes = releaseNotesElement?.querySelector('.PHBdkd')?.querySelector('.DWPxHb')?.text;
    } else {
      final scriptElements = document.getElementsByTagName('script');
      final infoScriptElement = scriptElements.firstWhere(
        (elm) => elm.text.contains('key: \'ds:4\''),
      );

      final param = infoScriptElement.text
          .substring(20, infoScriptElement.text.length - 2)
          .replaceAll('key:', '"key":')
          .replaceAll('hash:', '"hash":')
          .replaceAll('data:', '"data":')
          .replaceAll('sideChannel:', '"sideChannel":')
          .replaceAll('\'', '"');
      final parsed = json.decode(param);
      final data = parsed['data'];

      storeVersion = data[1][2][140][0][0][0];
      releaseNotes = data[1][2][144][1][1];
    }

    return AppVersions._(
      localVersion: Version.fromString(_getCleanVersion(packageInfo.version)),
      storeVersion: Version.fromString(_getCleanVersion(forceAppVersion ?? storeVersion)),
      appStoreLink: uri.toString(),
      releaseNotes: releaseNotes,
    );
  }

  /// Launches the Apple App Store or Google Play Store page for the app.
  Future<void> launchAppStore(String appStoreLink) async {
    debugPrint(appStoreLink);
    if (await canLaunch(appStoreLink)) {
      await launch(appStoreLink);
    } else {
      throw 'Could not launch appStoreLink';
    }
  }
}
