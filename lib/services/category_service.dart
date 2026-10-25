import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/constants.dart';
import '../models/category_model.dart';

class CategoryNameTakenException implements Exception {
  @override
  String toString() => 'A category with this name already exists.';
}

class CategoryInUseException implements Exception {
  @override
  String toString() =>
      'This category still has products. Move or remove them first.';
}

class CategoryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection(FirestoreCollections.categories);

  Stream<List<CategoryModel>> watchCategories({bool activeOnly = false}) {
    return _categories.orderBy('name').snapshots().map((snap) {
      final all =
          snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList();
      if (!activeOnly) return all;
      return all.where((c) => c.isActive).toList();
    });
  }

  Future<List<CategoryModel>> getActiveCategories() async {
    final snap = await _categories.orderBy('name').get();
    final all =
        snap.docs.map((d) => CategoryModel.fromMap(d.id, d.data())).toList();
    return all.where((c) => c.isActive).toList();
  }

  Future<Map<String, String>> getNameMap() async {
    final snap = await _categories.get();
    return {
      for (final doc in snap.docs) doc.id: (doc.data()['name'] ?? '').toString()
    };
  }

  Future<bool> _nameTaken(String name, {String? exceptId}) async {
    final wanted = name.toLowerCase();
    final snap = await _categories.get();
    return snap.docs.any((d) =>
        d.id != exceptId &&
        (d.data()['name'] ?? '').toString().trim().toLowerCase() == wanted);
  }

  Future<void> addCategory(String name,
      {String description = '', String? imageUrl}) async {
    final trimmed = name.trim();
    if (await _nameTaken(trimmed)) {
      throw CategoryNameTakenException();
    }
    await _categories.add({
      'name': trimmed,
      'description': description.trim(),
      'imageUrl': imageUrl,
      'isActive': true,
    });
  }

  Future<void> updateCategory(
    String categoryId, {
    required String name,
    required String description,
    String? imageUrl,
    required bool isActive,
  }) async {
    final trimmed = name.trim();
    if (await _nameTaken(trimmed, exceptId: categoryId)) {
      throw CategoryNameTakenException();
    }
    await _categories.doc(categoryId).update({
      'name': trimmed,
      'description': description.trim(),
      'imageUrl': imageUrl,
      'isActive': isActive,
    });
  }

  Future<void> setActive(String categoryId, bool isActive) async {
    await _categories.doc(categoryId).update({'isActive': isActive});
  }

  Future<void> deleteCategory(String categoryId) async {
    final inUse = await _firestore
        .collection(FirestoreCollections.products)
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    if (inUse.docs.isNotEmpty) {
      throw CategoryInUseException();
    }
    await _categories.doc(categoryId).delete();
  }
}
