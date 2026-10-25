import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/order_model.dart';
import '../models/report_model.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(FirestoreCollections.reports);

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestoreCollections.orders);

  DateTime _startOfPeriod(ReportPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case ReportPeriod.daily:
        return today;
      case ReportPeriod.weekly:
        return today.subtract(Duration(days: today.weekday - 1));
      case ReportPeriod.monthly:
        return DateTime(now.year, now.month, 1);
    }
  }

  Future<ReportModel> generateReport({
    required String farmerId,
    required ReportPeriod period,
  }) async {
    final now = DateTime.now();
    final startDate = _startOfPeriod(period, now);
    final endDate = now;

    final snap = await _orders
        .where('farmerId', isEqualTo: farmerId)
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
        .get();

    var totalOrders = 0;
    var revenue = 0.0;
    final qtyByProduct = <String, int>{};
    final revenueByProduct = <String, double>{};
    final nameByProduct = <String, String>{};

    for (final doc in snap.docs) {
      final order = OrderModel.fromMap(doc.id, doc.data());
      if (order.status == OrderStatus.cancelled) continue;

      totalOrders++;
      revenue += order.totalPrice;

      for (final item in order.items) {
        qtyByProduct[item.productId] =
            (qtyByProduct[item.productId] ?? 0) + item.qty;
        revenueByProduct[item.productId] =
            (revenueByProduct[item.productId] ?? 0) + item.subtotal;
        nameByProduct[item.productId] = item.itemName;
      }
    }

    final rankedProducts = revenueByProduct.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topProducts = rankedProducts
        .take(3)
        .map((e) => ReportTopProduct(
              productId: e.key,
              itemName: nameByProduct[e.key] ?? '',
              qty: qtyByProduct[e.key] ?? 0,
            ))
        .toList();

    final reportRef = _reports.doc();
    final report = ReportModel(
      reportId: reportRef.id,
      farmerId: farmerId,
      period: period,
      startDate: startDate,
      endDate: endDate,
      totalOrders: totalOrders,
      revenue: revenue,
      topProducts: topProducts,
      generatedAt: now,
    );

    await reportRef.set(report.toMap());
    return report;
  }

  Stream<List<ReportModel>> watchReports(String farmerId) {
    return _reports
        .where('farmerId', isEqualTo: farmerId)
        .orderBy('generatedAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ReportModel.fromMap(d.id, d.data())).toList());
  }
}
