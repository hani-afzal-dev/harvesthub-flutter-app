# Changes to make in the Word documentation

| Section | Change |
|---|---|
| 2.6 Our Tech Choices | Secret keys (OneSignal REST, Gemini, service account) live in a free Cloudflare Worker (`push_relay`), not in the APK. The app's `.env` holds only public ids and the unsigned Cloudinary preset. Firebase App Check was considered and rejected because sideloaded APKs may fail its check. |
| 2.7 Database Schema | Copy the table from `docs/firestore_schema.md`. New since the first draft: orders `customerName`, `promo_codes`, `promo_redemptions`, orders `promoCode` and `discount`, farmers `ratingSum`, `ratingCount`, `lastRatedOrderId`, products `itemNameLower`, `lastRestockOrderId`, orders `customerRating`. |
| 2.8 Environment and Config | Use the environment table in `README.md` (three places: app `.env`, relay secrets, `tools/.env`). |
| 3.2 Roles and Permissions | wishlists: a farmer can read only wishlist entries for their own products. products: a customer may lower `stockQty` only by a cart quantity deleted in the same write, and raise it only for their own cancelled order. pickup_slots: a customer may move `booked` by one. |
| 3.3 Firestore Security Rules | Replace with the current `firestore.rules`. Mention the 42 emulator checks in `tools/rules/rules.test.mjs`. |
| 3.4 Secrets and Credentials | The APK contains no secret keys. List the relay secrets and say they are set with `wrangler secret put`. |
| 3.11 Rate Limiting | Notification creation is allowed only with a real order or product link between sender and receiver. The relay limits the assistant to 20 questions per user per minute and only pushes notifications less than 10 minutes old. |
| 3.12 File Storage Security | The app uploads with an unsigned preset and never deletes. Unused photos are removed from a PC with `npm run images:cleanup`. |
| 3.14 Attack Scenarios | Rewrite scenario 2 (fake notification) to match the relationship rule and the relay's Firestore check. |
| 4.1 Traceability | Replace the "create: false" wording for notifications. Add customer rating and promo codes as added features. Recheck each row using `docs/requirement_check.md`. |
| Testing | 117 Flutter tests (`flutter test`) and 42 rules checks (`npm run test:rules`). |
| Data backup (SRS non-functional) | Managed scheduled exports need the Blaze plan, so a nightly GitHub Actions job exports every collection, encrypts it and keeps it for 30 days. |
