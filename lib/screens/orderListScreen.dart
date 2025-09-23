import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/orderItem.dart';
import '../models/product.dart';
import '../widgets/dbHelper.dart';
import '../screens/addOrderScreen.dart';

class OrderListScreen extends StatefulWidget {
  @override
  _OrderListScreenState createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  List<Order> _orders = [];
  List<OrderItem> _orderItems = [];
  List<Product> _products = [];
  DbHelper _dbHelper = DbHelper();

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    _orderItems = [];
    final orders = await _dbHelper.getShiftOrders();
    for (var order in orders) {
      var orderItems = await _dbHelper.getOrderItems(order.id!);
      _orderItems.addAll(orderItems);
    }
    final products = await _dbHelper.getProducts();
    setState(() {
      _orders = orders.reversed.toList();
      _products = products;
      _orderItems = _orderItems;
    });
  }

  Future<void> _refreshOrders() async {
    await _fetchOrders();
  }

  List<OrderItem> _getOrderItems(int orderId) {
    return _orderItems.where((item) => item.orderId == orderId).toList();
  }

  Product _getProductById(int productId) {
    return _products.firstWhere((item) => item.id == productId);
  }

  int _getItemQuantity(List<int>? productList, int productId) {
    return productList?.where((id) => id == productId).length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshOrders,
        child: _orders.isEmpty
            ? const Center(child: Text('No orders available'))
            : ListView.builder(
                itemCount: _orders.length,
                itemBuilder: (context, index) {
                  final order = _orders[index];
                  final orderItems = _getOrderItems(order.id!);
                  return Dismissible(
                    key: Key(order.id.toString()),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete_forever, color: Colors.white),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Confirm'),
                            content: const Text(
                                'Delete this order?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) {
                      _dbHelper.deleteOrder(order.id!);
                    },
                    child: Container(
                      color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                      child: ListTile(
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Order #: ${order.orderNumber}'),
                            Text('Date: ${order.dateTime}'),
                            Text('Customer: ${order.customerDetails}'),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Items in order:'),
                            ...orderItems.map((item) {
                                  final product = _getProductById(item.productId);
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${item.quantity} x ${product.name}'),
                                      if (product.isDeal)
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 25),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text('Deal includes:'),
                                              ...product.productList
                                                      ?.toSet()
                                                      .map((id) {
                                                    final dealItem =
                                                        _products.firstWhere(
                                                            (p) => p.id == id);
                                                    return Text(
                                                        '${_getItemQuantity(product.productList, id)} x ${dealItem.name}');
                                                  }).toList() ??
                                                  [],
                                            ],
                                          ),
                                        ),
                                    ],
                                  );
                                }).toList() ??
                                [],
                          ],
                        ),
                        trailing:
                            Text('Rs. ${order.totalPrice.toStringAsFixed(0)}'),
                        onTap: () {
                          _orderItems.clear();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddOrderScreen(
                                order: order,
                                onSave: _fetchOrders,
                              ),
                            ),                            
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddOrderScreen(onSave: _fetchOrders)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
