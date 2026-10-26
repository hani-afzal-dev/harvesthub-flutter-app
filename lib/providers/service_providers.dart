import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/admin_service.dart';
import '../services/ai_assistant_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/category_service.dart';
import '../services/cloudinary_service.dart';
import '../services/farmer_service.dart';
import '../services/follow_service.dart';
import '../services/location_service.dart';
import '../services/market_service.dart';
import '../services/notification_service.dart';
import '../services/order_service.dart';
import '../services/pickup_slot_service.dart';
import '../services/product_service.dart';
import '../services/promo_service.dart';
import '../services/push_token_service.dart';
import '../services/report_service.dart';
import '../services/wishlist_service.dart';
import '../services/account_deletion_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());
final aiAssistantServiceProvider =
    Provider<AiAssistantService>((ref) => AiAssistantService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final accountDeletionServiceProvider =
    Provider<AccountDeletionService>((ref) => AccountDeletionService());
final cartServiceProvider = Provider<CartService>((ref) => CartService());
final categoryServiceProvider =
    Provider<CategoryService>((ref) => CategoryService());
final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) => CloudinaryService());
final farmerServiceProvider = Provider<FarmerService>((ref) => FarmerService());
final followServiceProvider = Provider<FollowService>((ref) => FollowService());
final locationServiceProvider =
    Provider<LocationService>((ref) => LocationService());
final marketServiceProvider = Provider<MarketService>((ref) => MarketService());
final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());
final orderServiceProvider = Provider<OrderService>((ref) => OrderService());
final pickupSlotServiceProvider =
    Provider<PickupSlotService>((ref) => PickupSlotService());
final productServiceProvider =
    Provider<ProductService>((ref) => ProductService());
final promoServiceProvider = Provider<PromoService>((ref) => PromoService());
final pushTokenServiceProvider =
    Provider<PushTokenService>((ref) => PushTokenService());
final reportServiceProvider = Provider<ReportService>((ref) => ReportService());
final wishlistServiceProvider =
    Provider<WishlistService>((ref) => WishlistService());
