import 'package:cloud_firestore/cloud_firestore.dart';

class MarketModel {
  final String marketId;
  final String marketName;
  final String address;
  final GeoPoint? gpsCoordinates;
  final String operatingHours;
  final bool activeStatus;

  MarketModel({
    required this.marketId,
    required this.marketName,
    required this.address,
    this.gpsCoordinates,
    required this.operatingHours,
    required this.activeStatus,
  });

  double? get latitude => gpsCoordinates?.latitude;
  double? get longitude => gpsCoordinates?.longitude;

  factory MarketModel.fromMap(String id, Map<String, dynamic> map) {
    return MarketModel(
      marketId: id,
      marketName: map['marketName'] ?? '',
      address: map['address'] ?? '',
      gpsCoordinates: map['gpsCoordinates'] as GeoPoint?,
      operatingHours: map['operatingHours'] ?? '',
      activeStatus: map['activeStatus'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'marketName': marketName,
      'address': address,
      'gpsCoordinates': gpsCoordinates,
      'operatingHours': operatingHours,
      'activeStatus': activeStatus,
    };
  }
}
