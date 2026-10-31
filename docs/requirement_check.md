# Requirement check against the SRS

Checked by reading the code. `flutter analyze` reports no issues, `flutter test` passes 117 tests and `npm run test:rules` passes 42 rules checks in the emulator. "Built" means the code is there and compiles; items marked "Not measured" still need a device.

| SRS item | Where | Status |
|---|---|---|
| Landing page accepts role | `screens/common/role_selection_screen.dart` | Built |
| Customer register (name, email, phone, password, address) and login | `screens/auth/signup_screen.dart`, `login_screen.dart`, `core/validators.dart` | Built |
| Profile view, edit, change password, logout | `screens/customer/profile/profile_screen.dart`, `widgets/change_password_dialog.dart` | Built |
| Browse by category, product cards | `screens/customer/home/home_catalog_screen.dart`, `widgets/product_card.dart` | Built |
| Search by name, category, market, distance, farmer | `home_catalog_screen.dart`, `catalog_filter_sheet.dart` | Built |
| Product details, add to cart or wishlist | `product_details_screen.dart` | Built |
| Wishlist add, remove, view | `screens/customer/wishlist/wishlist_screen.dart` | Built |
| Cart add, change quantity, remove, subtotal | `screens/customer/cart/cart_screen.dart` | Built |
| Cart: clear the cart | `cart_screen.dart` (added in this phase) | Built |
| Simulated checkout with address and pickup slot | `checkout_screen.dart`, `services/order_service.dart` | Built |
| Order history (id, date, products, total, status) | `order_history_screen.dart` | Built |
| Change or cancel pickup booking | `order_history_screen.dart`, `order_service.dart` | Built |
| AI Farm Products Assistant with fallback | `services/ai_assistant_service.dart`, `core/ai_fallback_kb.dart` | Built |
| Follow or favorite farmers | `services/follow_service.dart`, `my_farmers_screen.dart` | Built |
| Restock alerts to wishlisters and followers | `services/product_service.dart` | Built |
| Order status push to customers | `order_service.dart`, `notification_service.dart`, `push_notification_service.dart` | Built |
| New order and booking change push to farmers | `order_service.dart` | Built |
| Low stock alert to farmer | `order_service.dart` | Built |
| Farmer: profile, add, edit, delete products, stock | `screens/farmer/**` | Built |
| Farmer: zero-stock products cannot be ordered | `order_service.dart` (transaction) | Built |
| Farmer: view orders and update status | `farmer_orders_screen.dart` | Built |
| Farmer: pickup slots | `farmer_pickup_slots_screen.dart`, `services/pickup_slot_service.dart` | Built |
| Farmer: daily, weekly, monthly reports | `farmer_reports_screen.dart`, `services/report_service.dart` | Built |
| Admin: customers, farmers, products, categories, orders | `screens/admin/**` | Built |
| Admin: reports (total orders, revenue by market, active farmers) | `admin_dashboard_screen.dart` | Built |
| About Us, Contact Us with feedback form | `screens/common/about_us_screen.dart`, `contact_us_screen.dart` | Built |
| Role-based access control | `firestore.rules`, role routing in `splash_screen.dart` | Built, 42 emulator checks pass |
| Data encrypted | Firebase in transit and at rest; local cache with SQLCipher | Built |
| Fast load, smooth transitions | pagination, cached images, encrypted cache | Not measured |
| Accessibility (clear fonts, navigation) | Material 3 widgets, tooltips, field labels, live error regions | Partly: no TalkBack audit done |
| Reliability | retry with backoff on reads, offline banner, saved data | Built |
| Data backup (scheduled auto-backups) | GitHub Actions nightly export + `tools/backup/restore.js` | Built (needs your two GitHub secrets) |

## Added in the final pass

| Item | Where |
|---|---|
| Unread notification badge on customer and farmer Profile tab and on the notification buttons | `widgets/unread_badge.dart` |
| `users.fcmToken` saved on login, sign-up and app start, cleared on logout | `services/push_token_service.dart` |
| Offline banner on login and sign-up | `login_screen.dart`, `signup_screen.dart` |
| Load more on customer orders, farmer orders, admin orders and notifications | `providers/*`, `widgets/load_more_button.dart` |
| Unused Cloudinary photos removed from a PC (the app has no secret to delete) | `tools/images/cleanup_images.js` |
| Promo codes with one use per customer, split across farms | `services/promo_service.dart`, `screens/admin/promos` |
| Secret keys moved out of the APK into a Cloudflare Worker | `push_relay/` |
| Seed data and test accounts | `tools/seed` |
| Scheduled backup on Spark (GitHub Actions, encrypted) and restore script | `.github/workflows/firestore-backup.yml`, `tools/backup` |
| Star rating and pickup sheet in their own files | `widgets/star_rating_widget.dart`, `screens/customer/orders/modify_pickup_sheet.dart` |
| `FollowedFarmerModel` | `models/followed_farmer_model.dart` |
| Tooltips on icon buttons, field labels and identifiers for screen readers and Test Lab | auth widgets, all screens |
| Fix: auth button with no action used to fake success (sign-up could open Home with invalid fields); it is now disabled | `widgets/animated_auth_button.dart` |

## Open items before submission (yours)

1. Deploy `firestore.rules` and the indexes (`firebase deploy --only firestore:rules,firestore:indexes`).
2. Deploy the relay and set its secrets (`push_relay/README.md`), then put `PUSH_RELAY_URL` in `.env`.
3. Add the notification icon from `docs/android_push_setup.md`.
4. Release keystore, SHA-1/SHA-256 in Firebase and a new `google-services.json` (`docs/release_build.md`).
5. Real phone test: push while the app is closed, push tap, airplane mode, image upload.
6. Rotate the OneSignal REST and Gemini keys that older APKs contained.
7. Record the demo video and update the Word report (`docs/docs_updates.md`).
8. Add `FIREBASE_SERVICE_ACCOUNT` and `BACKUP_PASSPHRASE` as GitHub secrets if you want the nightly backup.
9. Measure load time in profile mode and run a TalkBack pass.

## Known gaps

- Customer profile image is dropped from the plan: the users schema has no image field and it was optional.
- A photo uploaded and then abandoned without saving stays in Cloudinary until `npm run images:cleanup` runs.
- Farmers see the customer's name on an order but not their phone, because customer profiles are private in the rules.
- Admin dashboard totals read all orders once per open; fine at demo size.
