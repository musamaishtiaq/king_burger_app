import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/orderItem.dart';
import '../models/product.dart';
import '../widgets/dbHelper.dart';
import '../screens/orderDetailsScreen.dart';

class OrderProcessingScreen extends StatefulWidget {
  @override
  _OrderProcessingScreenState createState() => _OrderProcessingScreenState();
}

class _OrderProcessingScreenState extends State<OrderProcessingScreen> {
  final DbHelper _dbHelper = DbHelper();
  List<Order> _orders = [];
  List<OrderItem> _orderItems = [];
  List<Product> _products = [];
  Map<int, int> _itemQuantities = {};
  bool _showOrderList = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    SharedPreferences pref = await SharedPreferences.getInstance();
    int? orderCount = pref.getInt('numberOfOrders');
    _orders = await _dbHelper.getUnprocessedOrders(orderCount!);
    
    _fetchOrdersData();
  }

  Future<void> _fetchOrdersData() async {
    var orders = _orders;
    Map<int, int> itemQuantities = {};

    for (var order in orders) {
      var items = await _dbHelper.getOrderItems(order.id!);

      _orderItems.addAll(items);
      for (var item in items) {
        if (itemQuantities.containsKey(item.productId)) {
          itemQuantities[item.productId] =
              itemQuantities[item.productId]! + item.quantity!;
        } else {
          itemQuantities[item.productId] = item.quantity!;
        }
      }
    }

    for (var productId in itemQuantities.keys) {
      var product = await _dbHelper.getProduct(productId);
      _products.add(product!);
    }

    setState(() {
      _orders = orders;
      _orderItems = _orderItems;
      _products = _products;
      _itemQuantities = itemQuantities;
    });
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

  // void _updateOrderStatus() async {
  //   for (var order in _orders) {
  //     order.isProcessed = true;
  //     await _dbHelper.updateOrderStatus(order);
  //   }
  //   setState(() {
  //     _orders = [];
  //     _orderItems = [];
  //     _products = [];
  //     _itemQuantities = {};
  //   });

  //   _fetchOrders();
  // }

  Future<void> _updateOrderStatus(int orderId) async {
    var order = _orders.firstWhere((item) => item.id == orderId);
    order.isProcessed = true;
    await _dbHelper.updateOrderStatus(order);
    
    setState(() {
      _orders.removeWhere((item) => item.id == order.id);
      _orderItems = [];
      _products = [];
      _itemQuantities = {};
    });

    _fetchOrdersData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showOrderList ? _buildOrderList() : _buildItemList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fetchOrders();
        },
        child: Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showOrderList = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _showOrderList ? Colors.blue : Colors.grey,
              ),
              child: Text('Orders'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showOrderList = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: !_showOrderList ? Colors.blue : Colors.grey,
              ),
              child: Text('Order Items'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    return ListView.builder(
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        final orderItems = _getOrderItems(order.id!);
        return _orders.isEmpty
            ? Center(child: Text('No orders available for processing'))
            : Dismissible(
                key: Key(order.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.blue,
                  alignment: Alignment.centerRight,
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Icon(Icons.done, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Confirm'),
                        content:
                            Text('Are you sure you want to done this order?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text('Done'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  _updateOrderStatus(order.id!);
                },
                child: Container(
                  color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                  child: ListTile(
                    title: Text('Order #: ${order.orderNumber}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Items in order:'),
                        ...orderItems.map((item) {
                              final product = _getProductById(item.productId);
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${item.quantity} x ${product.name}'),
                                  if (product.isDeal)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 25),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Deal includes:'),
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
                        Text('Total: ${order.totalPrice.toStringAsFixed(0)}'),
                  ),
                ),
              );
      },
    );
  }

  Widget _buildItemList() {
    return ListView.builder(
      itemCount: _itemQuantities.keys.length,
      itemBuilder: (context, index) {
        final product = _getProductById(_itemQuantities.keys.elementAt(index));
        final quantity = _itemQuantities[product.id];
        return _itemQuantities.isEmpty
            ? Center(child: Text('No orders Items available for processing'))
            : Container(
                color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
                child: ListTile(
                  title: Text('Product: ${product.name}'),
                  subtitle: Text('Qty: $quantity'),
                ),
              );
      },
    );
  }
}
