import 'package:intl/intl.dart';

class Order {
  int? id;
  String orderNumber;
  String customerDetails;
  String dateTime;
  int? dateTimeEpoch;
  double totalPrice;
  bool isProcessed;
  bool isCashOnDelivery;

  static final DateFormat _storedDisplayFormat =
      DateFormat('yyyy-MM-dd hh:mm:ss a', 'en_US');

  static String formatStoredDateTime(DateTime dt) =>
      _storedDisplayFormat.format(dt);

  static DateTime? parseStoredDateTime(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty) return null;
    try {
      return DateTime.parse(s);
    } catch (_) {}
    try {
      return _storedDisplayFormat.parse(s);
    } catch (_) {}
    return null;
  }

  Order({
    this.id,
    required this.orderNumber,
    required this.customerDetails,
    required this.dateTime,
    this.dateTimeEpoch,
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
      'dateTimeEpoch': dateTimeEpoch,
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
      dateTimeEpoch: map['dateTimeEpoch'] as int?,
      totalPrice: map['totalPrice'],
      isProcessed: map['isProcessed'] == 1,
      isCashOnDelivery: map['isCashOnDelivery'] == 1,
    );
  }
}
