function encode(value, admin) {
  const { Timestamp, GeoPoint } = admin.firestore;
  if (value instanceof Timestamp) return { __type: 'timestamp', seconds: value.seconds, nanoseconds: value.nanoseconds };
  if (value instanceof GeoPoint) return { __type: 'geopoint', latitude: value.latitude, longitude: value.longitude };
  if (Array.isArray(value)) return value.map((item) => encode(item, admin));
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, encode(item, admin)]));
  }
  return value;
}

function decode(value, admin) {
  const { Timestamp, GeoPoint } = admin.firestore;
  if (Array.isArray(value)) return value.map((item) => decode(item, admin));
  if (value && typeof value === 'object') {
    if (value.__type === 'timestamp') return new Timestamp(value.seconds, value.nanoseconds);
    if (value.__type === 'geopoint') return new GeoPoint(value.latitude, value.longitude);
    return Object.fromEntries(Object.entries(value).map(([key, item]) => [key, decode(item, admin)]));
  }
  return value;
}

const collections = [
  'users', 'farmers', 'farmers_markets', 'categories', 'products', 'orders', 'wishlists',
  'cart_items', 'followed_farmers', 'pickup_slots', 'notifications', 'ai_chat_sessions', 'reports',
  'promo_codes', 'promo_redemptions',
];

module.exports = { encode, decode, collections };
