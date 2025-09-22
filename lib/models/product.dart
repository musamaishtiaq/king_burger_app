class Product {
  int? id;
  String name;
  int categoryId;
  double price;
  String info;
  bool isDeal;
  List<int>? productList;

  Product({
    this.id,
    required this.name,
    required this.categoryId,
    required this.price,
    required this.info,
    this.isDeal = false,
    this.productList,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'categoryId': categoryId,
      'price': price,
      'info': info,
      'isDeal': isDeal ? 1 : 0,
      'productList': productList?.join(',') ?? '',
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
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
    );
  }
}
