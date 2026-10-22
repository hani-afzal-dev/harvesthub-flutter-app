import 'package:cloud_firestore/cloud_firestore.dart';

class FollowedFarmerModel {
  final String followId;
  final String customerId;
  final String farmerId;
  final DateTime followedAt;

  FollowedFarmerModel({
    required this.followId,
    required this.customerId,
    required this.farmerId,
    required this.followedAt,
  });

  static String idFor(String customerId, String farmerId) =>
      '${customerId}_$farmerId';

  factory FollowedFarmerModel.fromMap(String id, Map<String, dynamic> map) {
    return FollowedFarmerModel(
      followId: id,
      customerId: map['customerId'] ?? '',
      farmerId: map['farmerId'] ?? '',
      followedAt: (map['followedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'customerId': customerId,
      'farmerId': farmerId,
      'followedAt': FieldValue.serverTimestamp(),
    };
  }
}
