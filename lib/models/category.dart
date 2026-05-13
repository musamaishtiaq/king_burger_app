class Category {
  int? id;
  String name;
  String? imagePath;
  bool isVisible;

  Category({
    this.id,
    required this.name,
    this.imagePath,
    this.isVisible = true,
  });

  Category copyWith({
    int? id,
    String? name,
    String? imagePath,
    bool? isVisible,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'isVisible': isVisible ? 1 : 0,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    final vis = map['isVisible'];
    return Category(
      id: map['id'],
      name: map['name'],
      imagePath: map['imagePath'] as String?,
      isVisible: vis == null ? true : vis == 1,
    );
  }
}
