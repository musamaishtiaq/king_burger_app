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
        title: const Text('Order Details'),
        elevation: 0,
      ),
      body: widget.showItems
          ? ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _orderItems.length,
              itemBuilder: (context, index) {
                final orderItem = _orderItems[index];
                return FutureBuilder<Product>(
                  future: Future.value(_getProductById(orderItem.productId)),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done &&
                        snapshot.hasData) {
                      final product = snapshot.data!;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            child: Icon(
                              Icons.inventory,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          title: Text(
                            product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text('Quantity: ${orderItem.quantity}'),
                              Text('Price: Rs. ${orderItem.price.toStringAsFixed(0)}'),
                            ],
                          ),
                          trailing: Text(
                            'Rs. ${(orderItem.quantity * orderItem.price).toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const Card(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        child: ListTile(
                          contentPadding: EdgeInsets.all(16),
                          leading: CircularProgressIndicator(),
                          title: Text('Loading...'),
                        ),
                      );
                    }
                  },
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              Icon(Icons.receipt, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Order Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.numbers),
                          title: const Text('Order Number'),
                          subtitle: Text(
                            widget.order.orderNumber,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.person),
                          title: const Text('Customer Details'),
                          subtitle: Text(
                            widget.order.customerDetails.isEmpty ? 'No customer details' : widget.order.customerDetails,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.access_time),
                          title: const Text('Date Time'),
                          subtitle: Text(
                            widget.order.dateTime,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.attach_money),
                          title: const Text('Total Price'),
                          subtitle: Text(
                            'Rs. ${widget.order.totalPrice.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
