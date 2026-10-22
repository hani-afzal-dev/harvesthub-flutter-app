import 'package:cloud_firestore/cloud_firestore.dart';

class FarmerModel {
  final String farmerId;
  final String userId;
  final String? marketId;
  final String businessName;
  final String description;
  final double rating;
  final int ratingSum;
  final int ratingCount;
  final String? imageUrl;
  final bool isVerified;
  final DateTime createdAt;

  FarmerModel({
    required this.farmerId,
    required this.userId,
    this.marketId,
    required this.businessName,
    required this.description,
    required this.rating,
    this.ratingSum = 0,
    this.ratingCount = 0,
    this.imageUrl,
    required this.isVerified,
    required this.createdAt,
  });

  factory FarmerModel.fromMap(String id, Map<String, dynamic> map) {
    final rawMarketId = map['marketId'] as String?;
    return FarmerModel(
      farmerId: id,
      userId: map['userId'] ?? id,
      marketId:
          (rawMarketId == null || rawMarketId.isEmpty) ? null : rawMarketId,
      businessName: map['businessName'] ?? '',
      description: map['description'] ?? '',
      rating: (map['rating'] ?? 0).toDouble(),
      ratingSum: ((map['ratingSum'] ?? 0) as num).toInt(),
      ratingCount: ((map['ratingCount'] ?? 0) as num).toInt(),
      imageUrl: map['imageUrl'] as String?,
      isVerified: map['isVerified'] ?? false,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'marketId': marketId,
      'businessName': businessName,
      'description': description,
      'rating': rating,
      'ratingSum': ratingSum,
      'ratingCount': ratingCount,
      'imageUrl': imageUrl,
      'isVerified': isVerified,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
