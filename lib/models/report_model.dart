import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportPeriod { daily, weekly, monthly }

ReportPeriod reportPeriodFromString(String value) {
  switch (value) {
    case 'weekly':
      return ReportPeriod.weekly;
    case 'monthly':
      return ReportPeriod.monthly;
    default:
      return ReportPeriod.daily;
  }
}

String reportPeriodToString(ReportPeriod period) {
  switch (period) {
    case ReportPeriod.weekly:
      return 'weekly';
    case ReportPeriod.monthly:
      return 'monthly';
    case ReportPeriod.daily:
      return 'daily';
  }
}

String reportPeriodLabel(ReportPeriod period) {
  switch (period) {
    case ReportPeriod.weekly:
      return 'Weekly';
    case ReportPeriod.monthly:
      return 'Monthly';
    case ReportPeriod.daily:
      return 'Daily';
  }
}

class ReportTopProduct {
  final String productId;
  final String itemName;
  final int qty;

  ReportTopProduct(
      {required this.productId, required this.itemName, required this.qty});

  factory ReportTopProduct.fromMap(Map<String, dynamic> map) {
    return ReportTopProduct(
      productId: map['productId'] ?? '',
      itemName: map['itemName'] ?? '',
      qty: ((map['qty'] ?? 0) as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'productId': productId, 'itemName': itemName, 'qty': qty};
  }
}

class ReportModel {
  final String reportId;
  final String farmerId;
  final ReportPeriod period;
  final DateTime startDate;
  final DateTime endDate;
  final int totalOrders;
  final double revenue;
  final List<ReportTopProduct> topProducts;
  final DateTime generatedAt;

  ReportModel({
    required this.reportId,
    required this.farmerId,
    required this.period,
    required this.startDate,
    required this.endDate,
    required this.totalOrders,
    required this.revenue,
    required this.topProducts,
    required this.generatedAt,
  });

  factory ReportModel.fromMap(String id, Map<String, dynamic> map) {
    final rawTopProducts = (map['topProducts'] as List?) ?? [];
    return ReportModel(
      reportId: id,
      farmerId: map['farmerId'] ?? '',
      period: reportPeriodFromString(map['period'] ?? 'daily'),
      startDate: (map['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (map['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      totalOrders: ((map['totalOrders'] ?? 0) as num).toInt(),
      revenue: ((map['revenue'] ?? 0) as num).toDouble(),
      topProducts: rawTopProducts
          .map((e) => ReportTopProduct.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      generatedAt:
          (map['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'farmerId': farmerId,
      'period': reportPeriodToString(period),
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'totalOrders': totalOrders,
      'revenue': revenue,
      'topProducts': topProducts.map((e) => e.toMap()).toList(),
      'generatedAt': FieldValue.serverTimestamp(),
    };
  }
}
