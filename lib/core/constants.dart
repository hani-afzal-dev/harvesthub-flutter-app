class FirestoreCollections {
  static const String users = 'users';
  static const String farmers = 'farmers';
  static const String farmersMarkets = 'farmers_markets';
  static const String categories = 'categories';
  static const String products = 'products';
  static const String orders = 'orders';
  static const String wishlists = 'wishlists';
  static const String cartItems = 'cart_items';
  static const String followedFarmers = 'followed_farmers';
  static const String pickupSlots = 'pickup_slots';
  static const String notifications = 'notifications';
  static const String aiChatSessions = 'ai_chat_sessions';
  static const String reports = 'reports';
  static const String promoCodes = 'promo_codes';
  static const String promoRedemptions = 'promo_redemptions';
}

class PromoTypes {
  static const String percent = 'percent';
  static const String flat = 'flat';
}

class OrderStatusValues {
  static const String pending = 'Pending';
  static const String confirmed = 'Confirmed';
  static const String readyForPickup = 'ReadyForPickup';
  static const String completed = 'Completed';
  static const String cancelled = 'Cancelled';
}

class NotificationTypes {
  static const String restockAlert = 'restock_alert';
  static const String orderStatus = 'order_status';
  static const String newOrder = 'new_order';
  static const String slotCancelled = 'slot_cancelled';
  static const String bookingModified = 'booking_modified';
}

class ProductUnits {
  static const List<String> all = ['kg', 'litre', 'dozen', 'piece'];
}

class StockRules {
  static const int lowStockThreshold = 5;
}

class OrderRules {
  static const int maxItemsPerOrder = 7;
}

class PagingRules {
  static const int pageSize = 20;
  static const int notificationBatchSize = 8;
}
