import 'package:flutter/material.dart';
import '../models/order.dart';
import '../widgets/dbHelper.dart';
import '../models/orderItem.dart';
import '../models/product.dart';
import '../utils/app_colors.dart';

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

  Product? _tryGetProduct(int productId) {
    for (final p in _products) {
      if (p.id == productId) return p;
    }
    return null;
  }

  String _orderItemTitle(OrderItem oi) {
    final snap = oi.productName.trim();
    if (snap.isNotEmpty) return snap;
    return _tryGetProduct(oi.productId)?.name ?? '(removed item)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Details'),
      ),
      body: widget.showItems
          ? ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: _orderItems.length,
              itemBuilder: (context, index) {
                final orderItem = _orderItems[index];
                final unitStr = orderItem.price.toStringAsFixed(0);
                final subStr =
                    (orderItem.quantity * orderItem.price).toStringAsFixed(0);
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.12),
                      child: Icon(
                        Icons.inventory,
                        color: AppColors.primary,
                      ),
                    ),
                    title: Text(
                      _orderItemTitle(orderItem),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          'Quantity: ${orderItem.quantity}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          'Rs. $unitStr × ${orderItem.quantity}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    trailing: Text(
                      'Rs. $subStr',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                );
              },
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.receipt, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Order Information',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
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
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.person),
                          title: const Text('Customer Details'),
                          subtitle: Text(
                            widget.order.customerDetails.isEmpty ? 'No customer details' : widget.order.customerDetails,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: const Icon(Icons.access_time),
                          title: const Text('Date Time'),
                          subtitle: Text(
                            widget.order.dateTime,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
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
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
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
