# Android push setup (OneSignal)

## Dashboard

- OneSignal > Settings > Push & In-App > Google Android (FCM): upload the Firebase service account JSON (Firebase console > Project settings > Service accounts > Generate new private key). The old "Server Key" is retired.
- Put the App ID in `.env` as `ONESIGNAL_APP_ID`. The REST API key never goes into the app: store it in the relay with `npx wrangler secret put ONESIGNAL_REST_API_KEY` (see `push_relay/README.md`).

## Notification icon (still to do)

- Add a white, transparent-background PNG named `ic_stat_onesignal_default` to each folder under `android/app/src/main/res/`:
  - `drawable-mdpi` 24x24
  - `drawable-hdpi` 36x36
  - `drawable-xhdpi` 48x48
  - `drawable-xxhdpi` 72x72
  - `drawable-xxxhdpi` 96x96
- Without it Android shows the default icon, which can render as a grey square in the status bar.

## Channels

- OneSignal creates its default channels on its own; no Dart or Kotlin code is needed.

## Permission

- Android 13+ shows the notification permission prompt through `lib/services/push_permission.dart` when it is useful: a customer placing an order or wishlisting an item, and a farmer opening their dashboard.
- Check `POST_NOTIFICATIONS` is present in the merged manifest (`android/app/build/intermediates/merged_manifests`) after a release build.

## Release build check

1. `flutter build apk --release`
2. Install on a real device, log in as a customer, then force-stop the app.
3. Change an order status from a farmer account. Tap the push from the tray: the app should open on the Orders tab.
4. Repeat with the app in the background, and once with the app open.
5. Restock push: tap should open the product details screen.
