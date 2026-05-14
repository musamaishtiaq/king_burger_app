class OrderItem {
  int? id;
  int orderId;
  int productId;
  int quantity;
  /// Unit price at order time (line subtotal is [quantity] * [price]).
  double price;

  /// Product title captured when the line is created/updated (survives catalog renames).
  String productName;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
    this.productName = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'quantity': quantity,
      'price': price,
      'productName': productName,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    final rawName = map['productName'];
    final nameStr = rawName == null ? '' : rawName.toString().trim();
    return OrderItem(
      id: map['id'],
      orderId: map['orderId'],
      productId: map['productId'],
      quantity: map['quantity'],
      price: map['price'],
      productName: nameStr,
    );
  }

  /// Snapshot on this line first; if empty (legacy row), [catalogName] from products.
  String lineDisplayLabel(String? catalogName) {
    final saved = productName.trim();
    if (saved.isNotEmpty) return saved;
    final live = (catalogName ?? '').trim();
    return live.isNotEmpty ? live : '(removed item)';
  }
}
