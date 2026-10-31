# Android and console setup

The Android project in this repository already contains these settings. This page lists them so they can be checked after regenerating any platform files.

## Already in the repository

- `AndroidManifest.xml`: `INTERNET` and location permissions, `android:allowBackup="false"` (restoring a backup without the Keystore key breaks the encrypted key storage), and `<queries>` for mailto, tel and https links used by Contact Us.
- `android/settings.gradle.kts` and `android/app/build.gradle.kts`: Google services and Crashlytics Gradle plugins.
- `minSdk` follows the Flutter default, which is high enough for `flutter_secure_storage`.
- iOS `Info.plist`: location and photo library permission texts.

## Firebase console

- Release & Monitor > Crashlytics > Enable.
- Analytics is already on.

## Check after building

1. `flutter pub get`, then `flutter analyze`.
2. First launch after updating: the old plain cache file is deleted and rebuilt automatically.
3. Airplane mode: the "No connection" bar appears above the bottom navigation. Home shows saved products, Orders shows saved orders, and the assistant header shows "Offline".
4. Log out and log in as someone else: the saved orders of the first account are gone.
5. Release build only: throw a test error and confirm it shows in Crashlytics within a few minutes. Debug builds do not send reports.
