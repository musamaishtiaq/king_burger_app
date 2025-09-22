class OrderItem {
  int? id;
  int orderId;
  int productId;
  int quantity;
  double price;

  OrderItem({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantity,
    required this.price,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderId': orderId,
      'productId': productId,
      'quantity': quantity,
      'price': price,
    };
  }

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'],
      orderId: map['orderId'],
      productId: map['productId'],
      quantity: map['quantity'],
      price: map['price'],
    );
  }
}
