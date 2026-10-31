# Firestore collections

Document ids marked "composite" are built as `customerId_productId`, `customerId_farmerId` or `customerId_CODE`, so the rules can check them and a second tap cannot create a duplicate.

| Collection | Document id | Fields |
|---|---|---|
| users | Firebase UID | name, email, phone, address, role (customer / farmer / admin), isActive, fcmToken, createdAt |
| farmers | same as users UID | userId, marketId (nullable), businessName, description, rating, ratingSum, ratingCount, lastRatedOrderId, imageUrl, isVerified, createdAt |
| farmers_markets | auto | marketName, address, gpsCoordinates (GeoPoint, nullable), operatingHours, activeStatus |
| categories | auto | name, description, imageUrl, isActive |
| products | auto | farmerId, categoryId, itemName, itemNameLower, description, pricePerUnit, unit (kg / litre / dozen / piece), stockQty, imageUrl, isAvailable, lastRestockOrderId, createdAt, updatedAt |
| orders | auto | customerId, customerName (copied from the profile at checkout, so the farmer can see it without reading customer profiles), farmerId, items [productId, itemName, qty, pricePerUnit, subtotal] (up to 7), totalPrice, promoCode (nullable), discount, status (Pending / Confirmed / ReadyForPickup / Completed / Cancelled), pickupSlotId, pickupSlotTime, deliveryAddr, customerRating (1 to 5, nullable), createdAt, updatedAt |
| wishlists | composite | customerId, productId, addedAt |
| cart_items | composite | customerId, productId, quantity, addedAt |
| followed_farmers | composite | customerId, farmerId, followedAt |
| pickup_slots | auto | farmerId, slotTime, capacity, booked, isActive |
| notifications | auto, or `new_order_<orderId>` | userId, type (restock_alert / order_status / new_order / slot_cancelled / booking_modified), message, relatedId, isRead, createdAt |
| ai_chat_sessions | auto | userId, createdAt, messages [role, content, timestamp] (new session after 50 messages) |
| reports | auto | farmerId, period (daily / weekly / monthly), startDate, endDate, totalOrders, revenue, topProducts [productId, itemName, qty] (top 3), generatedAt |
| promo_codes | the code, e.g. `FRESH20` | code, type (percent / flat), value, minOrder, maxDiscount, active, expiresAt, createdAt |
| promo_redemptions | composite (`customerId_CODE`) | customerId, code, discount, splits {orderId: amount}, redeemedAt |

Links: farmers.userId, products.farmerId, orders.customerId, orders.farmerId, pickup_slots.farmerId, reports.farmerId and notifications.userId point to a users id. products.categoryId points to categories. farmers.marketId points to farmers_markets. orders.pickupSlotId points to pickup_slots. orders.promoCode points to promo_codes. wishlists, cart_items and orders items point to products.

Helper fields used only by the rules: `farmers.lastRatedOrderId` proves a rating comes from a completed order, and `products.lastRestockOrderId` proves returned stock comes from a cancelled order.

Local SQLite cache (encrypted with SQLCipher): `products_cache` and `orders_cache`, created in `lib/core/local_db.dart`.
