import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/order.dart';
import '../models/orderItem.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../widgets/dbHelper.dart';

class AddOrderScreen extends StatefulWidget {
  final Function onSave;
  final Order? order;

  AddOrderScreen({required this.onSave, this.order});

  @override
  _AddOrderScreenState createState() => _AddOrderScreenState();
}

class _AddOrderScreenState extends State<AddOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  final DbHelper _dbHelper = DbHelper();

  // Order Info
  String _orderNumber = '';
  String _dateTime = '';
  String _customerDetails = '';
  bool _isCashOnDelivery = false;
  double _totalPrice = 0;
  int _count = 0;
  DateTime _currentDateTime = DateTime.now();

  // Data
  List<Category> _categories = [];
  List<Product> _products = [];
  List<OrderItem> _orderItems = [];
  int? _selectedCategoryId;

  // UI
  int _selectedTab = 0; // 0 = Items, 1 = Bill

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
    if (widget.order != null) {
      _orderNumber = widget.order!.orderNumber;
      _dateTime = widget.order!.dateTime;
      _customerDetails = widget.order!.customerDetails;
      _isCashOnDelivery = widget.order!.isCashOnDelivery;
      _fetchOrderItems(widget.order!.id!);
    } else {
      _orderNumber = DateFormat('kkmmss').format(_currentDateTime);
      _dateTime = DateFormat('yyyy-MM-dd hh:mm:ss a').format(_currentDateTime);
    }
  }

  Future<void> _fetchCategories() async {
    final cats = await _dbHelper.getCategories();
    setState(() => _categories = cats);
  }

  Future<void> _fetchProducts() async {
    final products = await _dbHelper.getProducts();
    setState(() => _products = products);
  }

  Future<void> _fetchOrderItems(int orderId) async {
    final items = await _dbHelper.getOrderItems(orderId);
    double price = 0;
    int cnt = 0;
    for (var e in items) {
      price += e.price;
      cnt += e.quantity;
    }
    setState(() {
      _orderItems = items;
      _totalPrice = price;
      _count = cnt;
    });
  }

  void _addProduct(Product product) {
    final existing = _orderItems.firstWhere(
      (item) => item.productId == product.id,
      orElse: () => OrderItem(
        orderId: widget.order?.id ?? 0,
        productId: product.id!,
        quantity: 0,
        price: 0,
      ),
    );

    if (existing.quantity == 0) {
      _orderItems.add(OrderItem(
        orderId: widget.order?.id ?? 0,
        productId: product.id!,
        quantity: 1,
        price: product.price,
      ));
    } else {
      existing.quantity++;
      existing.price += product.price;
    }

    _totalPrice += product.price;
    _count++;
    setState(() {});
  }

  void _removeProduct(Product product) {
    final existing = _orderItems.firstWhere(
      (item) => item.productId == product.id,
      orElse: () => OrderItem(orderId: 0, productId: 0, quantity: 0, price: 0),
    );

    if (existing.quantity > 0) {
      existing.quantity--;
      existing.price -= product.price;
      if (existing.quantity == 0) {
        _orderItems.remove(existing);
      }
      _totalPrice -= product.price;
      _count--;
      setState(() {});
    }
  }

  void _saveOrder() async {
    if (_formKey.currentState!.validate() && _orderItems.isNotEmpty) {
      final newOrder = Order(
        orderNumber: _orderNumber,
        customerDetails: _customerDetails,
        dateTime: _dateTime,
        totalPrice: _totalPrice,
        isProcessed: widget.order?.isProcessed ?? false,
        isCashOnDelivery: _isCashOnDelivery,
      );

      if (widget.order == null) {
        await _dbHelper.insertOrder(newOrder, _orderItems);
      } else {
        newOrder.id = widget.order!.id;
        await _dbHelper.updateOrder(newOrder, _orderItems);
      }

      widget.onSave();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _selectedCategoryId == null
        ? _products
        : _products.where((p) => p.categoryId == _selectedCategoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Add Order' : 'Edit Order'),
      ),
      body: Column(
        children: [
          // 🔹 Top Tabs
          Row(
            children: [
              _buildTopTab('Items', 0),
              _buildTopTab('Bill ($_count)', 1),
            ],
          ),
          const Divider(height: 1),

          // 🔹 Tab Body
          Expanded(
            child: _selectedTab == 0
                ? _buildItemsTab(filteredProducts)
                : _buildBillTab(),
          ),
        ],
      ),
    );
  }

  // ==============================
  // 🔵 WIDGETS
  // ==============================
  Widget _buildTopTab(String text, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          color: selected ? Colors.blue : Colors.grey[300],
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsTab(List<Product> filteredProducts) {
    return Column(
      children: [
        // 🔹 Horizontal Categories
        SizedBox(
          height: 60,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _categoryChip('All', null);
              }
              final cat = _categories[index - 1];
              return _categoryChip(cat.name, cat.id);
            },
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final existing = _orderItems.firstWhere(
                (item) => item.productId == product.id,
                orElse: () => OrderItem(orderId: 0, productId: 0, quantity: 0, price: 0),
              );
              return ListTile(
                title: Text(product.name),
                subtitle: Text('Rs. ${product.price.toStringAsFixed(0)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                        icon: const Icon(Icons.remove),
                        onPressed: () {
                          if (existing.quantity > 0) _removeProduct(product);
                        }),
                    Text(existing.quantity.toString()),
                    IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () => _addProduct(product)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBillTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ..._orderItems.map((item) {
            final product = _products.firstWhere((p) => p.id == item.productId);
            return ListTile(
              title: Text(product.name),
              subtitle: Text('Qty: ${item.quantity}'),
              trailing: Text('Rs. ${item.price.toStringAsFixed(0)}'),
            );
          }).toList(),
          const Divider(),
          Text('Total Items: $_count', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text('Total Price: Rs. ${_totalPrice.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          TextFormField(
            initialValue: _orderNumber,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Order Number'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            initialValue: _dateTime,
            readOnly: true,
            decoration: const InputDecoration(labelText: 'Date Time'),
            validator: (v) => v!.isEmpty ? 'Required' : null,
          ),
          TextFormField(
            initialValue: _customerDetails,
            decoration: const InputDecoration(labelText: 'Customer Details'),
            onChanged: (v) => _customerDetails = v,
          ),
          SwitchListTile(
            title: const Text('Cash On Delivery'),
            value: _isCashOnDelivery,
            onChanged: (v) => setState(() => _isCashOnDelivery = v),
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: _saveOrder,
            child: Text(widget.order == null ? 'Save Order' : 'Update Order'),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(String label, int? categoryId) {
    final selected = _selectedCategoryId == categoryId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) {
          setState(() => _selectedCategoryId = categoryId);
        },
        selectedColor: Colors.blue,
        backgroundColor: Colors.grey[300],
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      ),
    );
  }
}
