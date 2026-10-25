import '../core/app_logger.dart';
import '../core/local_db.dart';
import '../models/product_model.dart';

class ProductCacheService {
  Future<void> cacheProducts(List<ProductModel> products) async {
    try {
      final db = await LocalDb.instance;
      final now = DateTime.now().millisecondsSinceEpoch;

      final batch = db.batch();
      batch.delete('products_cache');
      for (final product in products) {
        batch.insert('products_cache', {
          'productId': product.productId,
          'farmerId': product.farmerId,
          'categoryId': product.categoryId,
          'itemName': product.itemName,
          'description': product.description,
          'pricePerUnit': product.pricePerUnit,
          'unit': product.unit,
          'stockQty': product.stockQty,
          'imageUrl': product.imageUrl,
          'isAvailable': product.isAvailable ? 1 : 0,
          'cachedAt': now,
        });
      }
      await batch.commit(noResult: true);
    } catch (e, stack) {
      AppLogger.error('Product cache write failed', e, stack);
    }
  }

  Future<List<ProductModel>> getCachedProducts() async {
    try {
      final db = await LocalDb.instance;
      final rows = await db.query('products_cache', orderBy: 'itemName');
      return rows.map((row) {
        final cachedAt =
            DateTime.fromMillisecondsSinceEpoch(row['cachedAt'] as int);
        return ProductModel(
          productId: row['productId'] as String,
          farmerId: row['farmerId'] as String,
          categoryId: row['categoryId'] as String,
          itemName: row['itemName'] as String,
          description: row['description'] as String,
          pricePerUnit: (row['pricePerUnit'] as num).toDouble(),
          unit: row['unit'] as String,
          stockQty: row['stockQty'] as int,
          imageUrl: row['imageUrl'] as String?,
          isAvailable: (row['isAvailable'] as int) == 1,
          createdAt: cachedAt,
          updatedAt: cachedAt,
        );
      }).toList();
    } catch (e, stack) {
      AppLogger.error('Product cache read failed', e, stack);
      return [];
    }
  }
}
