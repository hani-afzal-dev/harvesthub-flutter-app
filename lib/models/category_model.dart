class CategoryModel {
  final String categoryId;
  final String name;
  final String description;
  final String? imageUrl;
  final bool isActive;

  CategoryModel({
    required this.categoryId,
    required this.name,
    this.description = '',
    this.imageUrl,
    this.isActive = true,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      categoryId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] as String?,
      isActive: map['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'imageUrl': imageUrl,
      'isActive': isActive,
    };
  }
}
