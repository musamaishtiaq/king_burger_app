import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usb_serial/usb_serial.dart';

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

  bool? _customerSlipEnabled;
  bool? _internalSlipEnabled;
  bool? _custOrderDetails;
  bool? _custOrderItemsFull;
  bool? _custOrderItemsCount;
  bool? _custPayment;
  bool? _intOrderDetails;
  bool? _intOrderItemsFull;
  bool? _intOrderItemsCount;
  bool? _intPayment;

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
    _fetchPrintingChecks();
    _fetchCategories();
    _fetchProducts();
    if (widget.order != null) {
      _orderNumber = widget.order!.orderNumber;
      _dateTime = widget.order!.dateTime;
      _customerDetails = widget.order!.customerDetails;
      _isCashOnDelivery = widget.order!.isCashOnDelivery;
      _fetchOrderItems(widget.order!.id!);
    } else {
      _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(_currentDateTime);
    }
  }

  Future<void> _fetchPrintingChecks() async {
    final prefs = await SharedPreferences.getInstance();
    _customerSlipEnabled = prefs.getBool('customerSlipEnabled') ?? false;
    _internalSlipEnabled = prefs.getBool('internalSlipEnabled') ?? false;
    _custOrderDetails = prefs.getBool('custOrderDetails') ?? true;
    _custOrderItemsFull = prefs.getBool('custOrderItemsFull') ?? true;
    _custOrderItemsCount = prefs.getBool('custOrderItemsCount') ?? false;
    _custPayment = prefs.getBool('custPayment') ?? true;
    _intOrderDetails = prefs.getBool('intOrderDetails') ?? true;
    _intOrderItemsFull = prefs.getBool('intOrderItemsFull') ?? false;
    _intOrderItemsCount = prefs.getBool('intOrderItemsCount') ?? true;
    _intPayment = prefs.getBool('intPayment') ?? true;
    setState(() {});
  }

  Future<void> _fetchCategories() async {
    if (widget.order == null) {
      _orderNumber = await _dbHelper.getNextOrderNo();
    }
    final cats = await _dbHelper.getCategories();
    setState(() => _categories = [
      Category(id: -1, name: 'Selected'),
      ...cats.reversed.toList()
    ]);
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

  Product _getProductById(int productId) {
    return _products.firstWhere((item) => item.id == productId);
  }

  void _saveOrder() async {
    if (_formKey.currentState!.validate() && _orderItems.isNotEmpty) {
      final newOrder = Order(
        orderNumber: _orderNumber,
        customerDetails: _customerDetails,
        dateTime: _dateTime,
        totalPrice: _totalPrice,
        isProcessed: true,
        isCashOnDelivery: _isCashOnDelivery,
      );

      if (widget.order == null) {
        await _dbHelper.insertOrder(newOrder, _orderItems);
      } else {
        newOrder.id = widget.order!.id;
        await _dbHelper.updateOrder(newOrder, _orderItems);
      }

      if (_customerSlipEnabled!) {
        final bytes = await buildCustomerOrderSlip(newOrder, _orderItems);
        await printSlip(bytes);
      }
      if (_internalSlipEnabled!) {
        // final bytes = await buildCustomerOrderSlip(newOrder, _orderItems);
        // await printSlip(bytes);
      }

      widget.onSave();
      Navigator.of(context).pop();
    }
  }

  List<Product> _filterProducts() {
    List<Product> _filteredProducts = [];
    if (_selectedCategoryId == null) {
      _filteredProducts = _products;
    } else if (_selectedCategoryId == -1) {
      final selectedIds = _orderItems.map((item) => item.productId).toSet();
      _filteredProducts = _products.where((p) => selectedIds.contains(p.id)).toList();
    } else {
      _filteredProducts = _products.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    return _filteredProducts;
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filterProducts();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.order == null ? 'Add Order' : 'Edit Order'),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                _buildTopTab('Items', 0),
                _buildTopTab('Bill ($_count)', 1),
              ],
            ),
          ),
          Expanded(
            child: _selectedTab == 0
                ? _buildItemsTab(filteredProducts)
                : _buildBillTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopTab(String text, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 16,
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
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _categories.length + 1, // +1 for "All" option
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildCategoryChip(
                  label: 'All',
                  selected: _selectedCategoryId == null,
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                  },
                );
              }
              final cat = _categories[index - 1];
              return _buildCategoryChip(
                label: cat.name,
                selected: _selectedCategoryId == cat.id,
                onTap: () {
                  setState(() => _selectedCategoryId = cat.id);
                },
              );
            },
          ),
        ),
        const Divider(height: 1, thickness: 0.5),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: filteredProducts.length,
            itemBuilder: (context, index) {
              final product = filteredProducts[index];
              final existing = _orderItems.firstWhere(
                (item) => item.productId == product.id,
                orElse: () =>
                    OrderItem(orderId: 0, productId: 0, quantity: 0, price: 0),
              );
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  title: Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Rs. ${product.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: existing.quantity > 0 ? () => _removeProduct(product) : null,
                          color: existing.quantity > 0 ? Colors.red[600] : Colors.grey[400],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(
                            existing.quantity.toString(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _addProduct(product),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ],
                    ),
                  ),
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
          if (_orderItems.isNotEmpty) ...[
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Order Items',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ..._orderItems.map((item) {
                    final product = _products.firstWhere((p) => p.id == item.productId);
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      title: Text(product.name),
                      subtitle: Text('Qty: ${item.quantity}'),
                      trailing: Text(
                        'Rs. ${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Items:', style: Theme.of(context).textTheme.bodyLarge),
                        Text('$_count', style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Price:', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text(
                          'Rs. ${_totalPrice.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.receipt, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Order Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _orderNumber,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Order Number',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _dateTime,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date Time',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _customerDetails,
                    decoration: const InputDecoration(
                      labelText: 'Customer Details',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (v) => _customerDetails = v,
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Home Delivery'),
                    subtitle: const Text('Enable for delivery orders'),
                    value: _isCashOnDelivery,
                    onChanged: (v) => setState(() => _isCashOnDelivery = v),
                  ),
                ],
              ),
            ),
          ),
            const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _saveOrder,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              widget.order == null ? 'Save Order' : 'Update Order',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Theme.of(context).colorScheme.secondary,
        backgroundColor: Colors.grey[300],
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      ),
    );
  }

  Future<List<int>> buildCustomerOrderSlip(
      Order order, List<OrderItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    List<int> bytes = [];
    final shopName = prefs.getString('storeName') ?? "My Store";

    // ===== Order Details =====
    if (_custOrderDetails!) {
      bytes += generator.text(shopName,
          styles: const PosStyles(
              align: PosAlign.center, bold: true, height: PosTextSize.size2));
      bytes += generator.text('Order #: ${order.orderNumber}');
      bytes += generator.text('Date: ${order.dateTime}');
      bytes += generator.text('Order Slip: For Customer');
      if (order.isCashOnDelivery) {
        bytes += generator.text('Customer: ${order.customerDetails}');
        bytes += generator.text('Order Type: Home Delivery');
      }
      bytes += generator.hr();
    }

    // ===== Item List  =====
    double grandTotal = 0;
    if (_custOrderItemsFull!) {
      for (var item in items) {
        final name = _getProductById(item.productId).name;
        final qty = item.quantity;
        final price = item.price;
        final lineTotal = qty * price;
        grandTotal += lineTotal;

        bytes += generator.row([
          PosColumn(text: '$qty x $name', width: 8),
          PosColumn(
              text: lineTotal.toStringAsFixed(0),
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();
    }

    // ===== Item Count =====
    if (_custOrderItemsCount!) {
      for (var item in items) {
        final name = item.productId;
        final qty = item.quantity;
        final price = item.price;
        final lineTotal = qty * price;

        bytes += generator.row([
          PosColumn(text: '$qty x $name', width: 8),
          PosColumn(
              text: lineTotal.toStringAsFixed(0),
              width: 4,
              styles: const PosStyles(align: PosAlign.right)),
        ]);
      }
      bytes += generator.hr();
    }

    // ===== Payment =====
    if (_custPayment!) {
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(
            text: grandTotal.toStringAsFixed(0),
            width: 4,
            styles: const PosStyles(align: PosAlign.right, bold: true)),
      ]);
      bytes += generator.text('Thank you for ordering!',
          styles: const PosStyles(align: PosAlign.center));
    }

    bytes += generator.cut();
    return bytes;
  }

  Future<void> printSlip(List<int> bytes) async {
    final devices = await UsbSerial.listDevices();
    final printer =
        devices.firstWhere((d) => d.productName!.contains('TM-T90'));

    UsbPort? port = await printer.create();
    await port!.open();
    await port.setDTR(true);
    await port.write(Uint8List.fromList(bytes));
    await port.close();
  }
}
