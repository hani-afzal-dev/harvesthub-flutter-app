import '../models/product_model.dart';

List<ProductModel> matchProductsByName(
    List<ProductModel> pool, String query, int limit) {
  final words = <String>[];
  for (final word in query.trim().toLowerCase().split(RegExp(r'\s+'))) {
    if (word.isNotEmpty) words.add(word);
  }
  if (words.isEmpty) return [];

  final startsWith = <ProductModel>[];
  final contains = <ProductModel>[];
  for (final product in pool) {
    final name = product.itemName.toLowerCase();
    var allFound = true;
    for (final word in words) {
      if (!name.contains(word)) {
        allFound = false;
        break;
      }
    }
    if (!allFound) continue;
    if (name.startsWith(words.first)) {
      startsWith.add(product);
    } else {
      contains.add(product);
    }
  }

  final results = [...startsWith, ...contains];
  if (results.length > limit) return results.sublist(0, limit);
  return results;
}
