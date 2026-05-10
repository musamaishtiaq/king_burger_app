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
import '../utils/app_colors.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/local_image.dart';

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
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(18),
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
        ),
      ),
    );
  }

  Widget _buildTopTab(String text, int index) {
    final selected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
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
        Container(
          height: 68,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          itemCount: _categories.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildCategoryChip(
                  label: 'All',
                  imagePath: null,
                  selected: _selectedCategoryId == null,
                  onTap: () {
                    setState(() => _selectedCategoryId = null);
                  },
                );
              }
              final cat = _categories[index - 1];
              return _buildCategoryChip(
                label: cat.name,
                imagePath: cat.imagePath,
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
          child: filteredProducts.isEmpty
              ? Center(
                  child: Text(
                    'No items in this category',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final existing = _orderItems.firstWhere(
                      (item) => item.productId == product.id,
                      orElse: () => OrderItem(
                        orderId: 0,
                        productId: 0,
                        quantity: 0,
                        price: 0,
                      ),
                    );
                    return Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LocalOrAssetImage(
                                  path: product.imagePath,
                                  entity: LocalImageEntity.product,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            Text(
                              'Rs. ${product.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed: existing.quantity > 0
                                        ? () => _removeProduct(product)
                                        : null,
                                    color: existing.quantity > 0
                                        ? AppColors.error
                                        : AppColors.disabled,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Text(
                                    existing.quantity.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                    ),
                                    onPressed: () => _addProduct(product),
                                    color: AppColors.primary,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                            ),
                          ],
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (_orderItems.isNotEmpty) ...[
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_cart, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Order Items',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
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
                      subtitle: Text(
                        'Qty: ${item.quantity}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Text(
                        'Rs. ${item.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Items:', style: Theme.of(context).textTheme.bodyLarge),
                        Text(
                          '$_count',
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
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
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
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
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.receipt, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Order Details',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
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
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _customerDetails,
                    decoration: const InputDecoration(
                      labelText: 'Customer Details',
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
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              widget.order == null ? 'Save Order' : 'Update Order',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required String? imagePath,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            width: 28,
            height: 28,
            child: LocalOrAssetImage(
              path: imagePath,
              entity: LocalImageEntity.category,
              fit: BoxFit.cover,
              width: 28,
              height: 28,
            ),
          ),
        ),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        backgroundColor: const Color(0xFFF0F0F0),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          color: selected ? AppColors.primary : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
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
