import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants.dart';
import '../core/retry.dart';
import '../models/market_model.dart';
import 'location_service.dart';

class MarketInUseException implements Exception {
  @override
  String toString() =>
      'Farmers are still linked to this market. Move them to another market first, or turn the market off instead.';
}

class MarketWithDistance {
  final MarketModel market;
  final double? distanceKm;

  MarketWithDistance({required this.market, required this.distanceKm});
}

class MarketService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocationService _locationService = LocationService();

  CollectionReference<Map<String, dynamic>> get _markets =>
      _firestore.collection(FirestoreCollections.farmersMarkets);

  Future<List<MarketModel>> getActiveMarkets() async {
    final marketsQuery = _markets.where('activeStatus', isEqualTo: true);
    final snap = await getWithCacheFallback(marketsQuery);
    return snap.docs.map((d) => MarketModel.fromMap(d.id, d.data())).toList();
  }

  Stream<List<MarketModel>> watchAllMarkets() {
    return _markets.orderBy('marketName').snapshots().map((snap) =>
        snap.docs.map((d) => MarketModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> saveMarket(MarketModel market) async {
    if (market.marketId.isEmpty) {
      await _markets.add(market.toMap());
    } else {
      await _markets.doc(market.marketId).set(market.toMap());
    }
  }

  Future<void> setActive(String marketId, bool active) async {
    await _markets.doc(marketId).update({'activeStatus': active});
  }

  Future<void> deleteMarket(String marketId) async {
    final linked = await _firestore
        .collection(FirestoreCollections.farmers)
        .where('marketId', isEqualTo: marketId)
        .limit(1)
        .get();
    if (linked.docs.isNotEmpty) throw MarketInUseException();
    await _markets.doc(marketId).delete();
  }

  List<MarketWithDistance> withDistanceFrom(
      List<MarketModel> markets, Position? position) {
    final result = markets.map((market) {
      if (position == null ||
          market.latitude == null ||
          market.longitude == null) {
        return MarketWithDistance(market: market, distanceKm: null);
      }
      final distance = _locationService.distanceKm(
        position.latitude,
        position.longitude,
        market.latitude!,
        market.longitude!,
      );
      return MarketWithDistance(market: market, distanceKm: distance);
    }).toList();

    result.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });
    return result;
  }
}
