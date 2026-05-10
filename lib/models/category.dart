class Category {
  int? id;
  String name;
  String? imagePath;

  Category({
    this.id,
    required this.name,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'],
      name: map['name'],
      imagePath: map['imagePath'] as String?,
    );
  }
}
