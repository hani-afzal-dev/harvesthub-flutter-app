# Release build

## 1. Keystore

```
keytool -genkey -v -keystore <keystore-name>.jks -keyalg RSA -keysize 2048 -validity 10000 -alias <alias>
```

Move the file to `android/app/` and keep a backup copy somewhere safe. Never commit it (`*.jks` is git-ignored).

## 2. android/key.properties

```
storePassword=<your password>
keyPassword=<your password>
keyAlias=<alias>
storeFile=<keystore-name>.jks
```

`android/app/build.gradle.kts` already reads this file. Without it, release builds fall back to the debug key so `flutter run --release` still works.

## 3. Firebase and Google sign-in

```
keytool -list -v -keystore android/app/<keystore-name>.jks -alias <alias>
```

Add the SHA-1 and SHA-256 lines to Firebase console > Project settings > Your Android app, download the new `google-services.json` into `android/app/`, and rebuild. Google sign-in fails on the release APK until this is done.

## 4. Build

```
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The APK is in `build/app/outputs/flutter-apk/app-release.apk`. Install it on a real phone and run through the customer, farmer and admin flows once.

## 5. What to submit

- Source code zip without `.env`, `tools/.env`, `tools/serviceAccountKey.json`, `push_relay/.dev.vars`, the keystore and `key.properties`
- `README.md` with test accounts and assumptions
- The APK
- `docs/firestore_schema.md` and `firestore.rules`
- Project report (Word) without source code
- Demo video (.mp4)
