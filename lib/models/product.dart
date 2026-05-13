class Product {
  int? id;
  String name;
  int categoryId;
  double price;
  String info;
  bool isDeal;
  List<int>? productList;
  String? imagePath;
  bool isVisible;

  Product({
    this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.info,
    this.isDeal = false,
    this.productList,
    this.imagePath,
    this.isVisible = true,
  });

  Product copyWith({
    int? id,
    String? name,
    int? categoryId,
    double? price,
    String? info,
    bool? isDeal,
    List<int>? productList,
    String? imagePath,
    bool? isVisible,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      price: price ?? this.price,
      info: info ?? this.info,
      isDeal: isDeal ?? this.isDeal,
      productList: productList ?? this.productList,
      imagePath: imagePath ?? this.imagePath,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'price': price,
      'info': info,
      'isDeal': isDeal ? 1 : 0,
      'productList': productList?.join(',') ?? '',
      'imagePath': imagePath,
      'isVisible': isVisible ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    final vis = map['isVisible'];
    return Product(
      id: map['id'],
      name: map['name'],
      categoryId: map['categoryId'],
      price: map['price'],
      info: map['info'],
      isDeal: map['isDeal'] == 1 ? true : false,
      productList: map['productList'] != null && map['productList'] != ''
          ? List<int>.from((map['productList'] as String).split(',').map((e) => int.parse(e)))
          : [],
      imagePath: map['imagePath'] as String?,
      isVisible: vis == null ? true : vis == 1,
    );
  }
}
