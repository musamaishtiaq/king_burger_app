class Order {
  int? id;
  String orderNumber;
  String customerDetails;
  String dateTime;
  double totalPrice;
  bool isProcessed;
  bool isCashOnDelivery;

  Order({
    this.id,
    required this.orderNumber,
    required this.customerDetails,
    required this.dateTime,
    required this.totalPrice,
    this.isProcessed = false,
    this.isCashOnDelivery = false,
  });

  // Convert a Order object into a Map object
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'customerDetails': customerDetails,
      'dateTime': dateTime,
      'totalPrice': totalPrice,
      'isProcessed': isProcessed ? 1 : 0,
      'isCashOnDelivery': isCashOnDelivery ? 1 : 0,
    };
  }

  // Extract a Order object from a Map object
  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'],
      orderNumber: map['orderNumber'],
      customerDetails: map['customerDetails'],
      dateTime: map['dateTime'],
      totalPrice: map['totalPrice'],
      isProcessed: map['isProcessed'] == 1,
      isCashOnDelivery: map['isCashOnDelivery'] == 1,
    );
  }
}
