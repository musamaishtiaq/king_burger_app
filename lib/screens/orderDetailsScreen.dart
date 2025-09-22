import 'package:flutter/material.dart';
import '../models/order.dart';
import '../widgets/dbHelper.dart';
import '../models/orderItem.dart';
import '../models/product.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Order order;
  final bool showItems;

  OrderDetailsScreen({required this.order, required this.showItems});

  @override
  _OrderDetailsScreenState createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  List<OrderItem> _orderItems = [];
  List<Product> _products = [];
  DbHelper _dbHelper = DbHelper();

  @override
  void initState() {
    super.initState();
    _fetchOrderItems();
  }

  Future<void> _fetchOrderItems() async {
    final orderItems = await _dbHelper.getOrderItems(widget.order.id!);
    final products = await _dbHelper.getProducts();
    setState(() {
      _orderItems = orderItems;
      _products = products;
    });
  }

  Product _getProductById(int productId) {
    return _products.firstWhere((item) => item.id == productId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order Details'),
      ),
      body: widget.showItems
          ? ListView.builder(
              itemCount: _orderItems.length,
              itemBuilder: (context, index) {
                final orderItem = _orderItems[index];
                return FutureBuilder<Product>(
                  future: Future.value(_getProductById(orderItem.productId)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      final product = snapshot.data!;
                      return ListTile(
                        title: Text(product.name),
                        subtitle: Text(
                            'Quantity: ${orderItem.quantity}, Price: ${orderItem.price.toStringAsFixed(2)}'),
                      );
                    } else {
                      return CircularProgressIndicator();
                    }
                  },
                );
              },
            )
          : Column(
              children: [
                ListTile(
                  title: Text('Order Number'),
                  subtitle: Text(widget.order.orderNumber),
                ),
                ListTile(
                  title: Text('Customer Details'),
                  subtitle: Text(widget.order.customerDetails),
                ),
                ListTile(
                  title: Text('Date Time'),
                  subtitle: Text(widget.order.dateTime),
                ),
                ListTile(
                  title: Text('Total Price'),
                  subtitle: Text(widget.order.totalPrice.toStringAsFixed(2)),
                ),
              ],
            ),
    );
  }
}
