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
      appBar: AppBar(
        title: const Text('Order Processing'),
        elevation: 0,
      ),
      body: _showOrderList ? _buildOrderList() : _buildItemList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _fetchOrders();
        },
        child: const Icon(Icons.refresh),
        tooltip: 'Refresh Orders',
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showOrderList = true;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showOrderList ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                  foregroundColor: _showOrderList ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Orders'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showOrderList = false;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_showOrderList ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                  foregroundColor: !_showOrderList ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Order Items'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderList() {
    return _orders.isEmpty
        ? _buildEmptyOrderState()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              final order = _orders[index];
              final orderItems = _getOrderItems(order.id!);
              return Dismissible(
                key: Key(order.id.toString()),
                direction: DismissDirection.endToStart,
                background: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.done, color: Colors.white, size: 24),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: const Text('Complete Order'),
                        content: const Text('Are you sure you want to mark this order as completed?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                            child: const Text('Complete'),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  _updateOrderStatus(order.id!);
                },
                child: Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Rs. ${order.totalPrice.toStringAsFixed(0)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Items in order:',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...orderItems.map((item) {
                          final product = _getProductById(item.productId);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Row(
                              children: [
                                Text(
                                  '${item.quantity}x ',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                Expanded(
                                  child: Text(product.name),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        if (orderItems.any((item) => _getProductById(item.productId).isDeal)) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Deal includes:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[700],
                                  ),
                                ),
                                const SizedBox(height: 3),
                                ...orderItems.where((item) => _getProductById(item.productId).isDeal).map((item) {
                                  final product = _getProductById(item.productId);
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        ...product.productList?.toSet().map((id) {
                                          final dealItem = _products.firstWhere((p) => p.id == id);
                                          return Text(
                                            '• ${_getItemQuantity(product.productList, id)}x ${dealItem.name}',
                                            style: TextStyle(color: Colors.orange[700]),
                                          );
                                        }).toList() ?? [],
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildItemList() {
    return _itemQuantities.isEmpty
        ? _buildEmptyItemState()
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: _itemQuantities.keys.length,
            itemBuilder: (context, index) {
              final product = _getProductById(_itemQuantities.keys.elementAt(index));
              final quantity = _itemQuantities[product.id];
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
                  subtitle: Text('Total quantity needed'),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$quantity',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            },
          );
  }

  Widget _buildEmptyOrderState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Orders to Process',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All orders have been processed or no new orders available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyItemState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No Items to Process',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No order items available for processing',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
