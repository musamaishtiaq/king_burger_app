import 'dart:io';
import 'dart:math' as math;

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as im;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/orderItem.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../widgets/dbHelper.dart';
import '../utils/app_colors.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/local_image.dart';
import '../utils/receipt_section_raster.dart';

/// Fixed 80mm (~3") thermal paper; slip column layout assumes this width.
const PaperSize kReceiptPaperSize = PaperSize.mm80;

/// Bitmap max side for receipt logo (~0.75" at 203 DPI, common on ESC/POS).
const int kReceiptLogoMaxSidePx = 152;

im.Image _resizeImageToReceiptLogoBox(im.Image src) {
  if (src.width <= kReceiptLogoMaxSidePx &&
      src.height <= kReceiptLogoMaxSidePx) {
    return src;
  }
  final scale = math.min(
    kReceiptLogoMaxSidePx / src.width,
    kReceiptLogoMaxSidePx / src.height,
  );
  final nw = math.max(1, (src.width * scale).round());
  final nh = math.max(1, (src.height * scale).round());
  return im.copyResize(src, width: nw, height: nh);
}

/// Full slip-width canvas with the logo centered, so raster print is centered
/// even when the printer ignores [PosAlign.center] for [Generator.image].
im.Image _centerReceiptLogoOnSlipWidth(im.Image resizedLogo) {
  final slipW = kReceiptPaperSize.width;
  final canvas = im.Image(slipW, resizedLogo.height);
  canvas.fill(0xFFFFFFFF);
  im.copyInto(canvas, resizedLogo, center: true);
  return canvas;
}

/// Match ESC/POS slip width when widget capture is off by a few pixels.
im.Image _normalizeSlipRasterWidth(im.Image src) {
  final target = kReceiptPaperSize.width;
  if (src.width == target) return src;
  final nh = math.max(1, (src.height * target / src.width).round());
  return im.copyResize(src, width: target, height: nh);
}

/// [Generator.text] with [PosAlign.center] does not center on many printers because
/// `_text` defaults to absolute column 0; a 1+11 [row] applies true horizontal centering.
List<int> _slipCenteredTextRow(
  Generator generator,
  String text, {
  PosStyles styles = const PosStyles(align: PosAlign.center),
}) {
  return generator.row([
    PosColumn(text: '', width: 1, styles: const PosStyles()),
    PosColumn(text: text, width: 11, styles: styles),
  ]);
}

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
  bool _isSaving = false;
  void initState() {
    super.initState();
    _fetchPrintingChecks();
    if (widget.order != null) {
      _orderNumber = widget.order!.orderNumber;
      _dateTime = widget.order!.dateTime;
      _customerDetails = widget.order!.customerDetails;
      _isCashOnDelivery = widget.order!.isCashOnDelivery;
      _bootstrapEditOrder();
    } else {
      _dateTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(_currentDateTime);
      _bootstrapNewOrder();
    }
  }

  Future<void> _bootstrapNewOrder() async {
    await Future.wait([_fetchCategories(), _fetchProducts()]);
  }

  Future<void> _bootstrapEditOrder() async {
    await _fetchOrderItems(widget.order!.id!);
    await Future.wait([_fetchCategories(), _fetchProducts()]);
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
    final cats = await _dbHelper.getVisibleCategories();
    setState(
      () => _categories = [
        Category(id: -1, name: 'Selected'),
        ...cats.reversed.toList(),
      ],
    );
  }

  Future<void> _fetchProducts() async {
    final visible = await _dbHelper.getVisibleCatalogProducts();
    if (widget.order == null) {
      setState(() => _products = visible);
      return;
    }
    final idsInOrder = _orderItems.map((e) => e.productId).toSet();
    final visibleIds = visible.map((p) => p.id!).toSet();
    final missing = idsInOrder.difference(visibleIds);
    final merged = List<Product>.from(visible);
    for (final id in missing) {
      final p = await _dbHelper.getProduct(id);
      if (p != null) merged.add(p);
    }
    merged.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    setState(() => _products = merged);
  }

  String? _categoryImagePath(int categoryId) {
    for (final c in _categories) {
      if (c.id == categoryId) return c.imagePath;
    }
    return null;
  }

  Future<void> _fetchOrderItems(int orderId) async {
    final items = await _dbHelper.getOrderItems(orderId);
    double price = 0;
    int cnt = 0;
    for (var e in items) {
      price += e.price * e.quantity;
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
      _orderItems.add(
        OrderItem(
          orderId: widget.order?.id ?? 0,
          productId: product.id!,
          quantity: 1,
          price: product.price,
        ),
      );
    } else {
      existing.quantity++;
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

  /// Occurrences of a component product in the deal template (per one deal ordered).
  int _dealTemplateCount(List<int>? productList, int componentProductId) {
    if (productList == null || productList.isEmpty) return 0;
    return productList.where((id) => id == componentProductId).length;
  }

  /// Per underlying product: non-deals add line quantity; deals expand to components
  /// (line qty × template counts), so standalone items and deal contents combine correctly.
  Map<int, int> _kitchenCountsByProductId(List<OrderItem> items) {
    final counts = <int, int>{};
    void addCount(int productId, int delta) {
      if (delta <= 0) return;
      counts[productId] = (counts[productId] ?? 0) + delta;
    }

    for (final item in items) {
      final product = _getProductById(item.productId);
      final q = item.quantity;
      final list = product.productList;

      if (product.isDeal && list != null && list.isNotEmpty) {
        for (final componentId in list.toSet()) {
          final perDealUnit = _dealTemplateCount(list, componentId);
          addCount(componentId, q * perDealUnit);
        }
      } else {
        addCount(product.id!, q);
      }
    }
    return counts;
  }

  void _saveOrder() async {
    if (!_formKey.currentState!.validate() || _orderItems.isEmpty) return;
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _fetchPrintingChecks();
      final newOrder = Order(
        orderNumber: _orderNumber,
        customerDetails: _customerDetails,
        dateTime: _dateTime,
        totalPrice: _totalPrice,
        isProcessed: true,
        isCashOnDelivery: _isCashOnDelivery,
      );

      if (widget.order == null) {
        final allowed = await _dbHelper.canInsertOrderWithNumber(_orderNumber);
        if (!allowed) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'This order number was already saved twice in the last 24 hours. Open a new order or try later.',
                ),
              ),
            );
          }
          return;
        }
        await _dbHelper.insertOrder(newOrder, _orderItems);
      } else {
        newOrder.id = widget.order!.id;
        await _dbHelper.updateOrder(newOrder, _orderItems);
      }

      if (_customerSlipEnabled!) {
        try {
          final bytes = await _buildOrderSlip(
            newOrder,
            _orderItems,
            forCustomer: true,
          );
          await printSlip(bytes);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Customer print failed: $e')),
            );
          }
        }
      }
      if (_internalSlipEnabled!) {
        try {
          final bytes = await _buildOrderSlip(
            newOrder,
            _orderItems,
            forCustomer: false,
          );
          await printSlip(bytes);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Kitchen print failed: $e')));
          }
        }
      }

      widget.onSave();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  List<Product> _filterProducts() {
    List<Product> _filteredProducts = [];
    if (_selectedCategoryId == null) {
      _filteredProducts = _products;
    } else if (_selectedCategoryId == -1) {
      final selectedIds = _orderItems.map((item) => item.productId).toSet();
      _filteredProducts = _products
          .where((p) => selectedIds.contains(p.id))
          .toList();
    } else {
      _filteredProducts = _products
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
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
                margin: EdgeInsets.fromLTRB(
                  horizontalScreenPadding(context),
                  12,
                  horizontalScreenPadding(context),
                  8,
                ),
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
            padding: EdgeInsets.symmetric(
              horizontal: horizontalScreenPadding(context),
            ),
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
                  padding: EdgeInsets.fromLTRB(
                    horizontalScreenPadding(context),
                    8,
                    horizontalScreenPadding(context),
                    16,
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: catalogGridCrossAxisCount(context),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: orderItemsGridChildAspectRatio(context),
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
                                  fallbackPath: _categoryImagePath(
                                    product.categoryId,
                                  ),
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
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
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
                                    icon: const Icon(Icons.add_circle_outline),
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          if (_orderItems.isNotEmpty) ...[
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.shopping_cart,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Order Items',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  ..._orderItems.map((item) {
                    final match = _products.where(
                      (p) => p.id == item.productId,
                    );
                    final name = match.isEmpty
                        ? '(removed item)'
                        : match.first.name;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 2,
                      ),
                      title: Text(name),
                      subtitle: Text(
                        'Qty: ${item.quantity}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      trailing: Text(
                        'Rs. ${(item.quantity * item.price).toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Items:',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          '$_count',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Price:',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rs. ${_totalPrice.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
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
            const SizedBox(height: 8),
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _orderNumber,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Order Number',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _dateTime,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Date Time',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: _customerDetails,
                    decoration: const InputDecoration(
                      labelText: 'Customer Details',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (v) => _customerDetails = v,
                  ),
                  const SizedBox(height: 8),
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
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isSaving ? null : _saveOrder,
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

  String _slipShortName(String name, int maxLen) {
    final t = name.trim();
    if (t.length <= maxLen) return t;
    return t.substring(0, maxLen);
  }

  Future<List<int>> _buildOrderSlip(
    Order order,
    List<OrderItem> items, {
    required bool forCustomer,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final profile = await CapabilityProfile.load();
    final generator = Generator(kReceiptPaperSize, profile);
    List<int> bytes = [];
    final shopName = prefs.getString('storeName') ?? "My Store";
    final grandTotal = items.fold<double>(
      0.0,
      (sum, item) => sum + item.quantity * item.price,
    );

    final showDetails = forCustomer ? _custOrderDetails! : _intOrderDetails!;
    final showItemsFull = forCustomer
        ? _custOrderItemsFull!
        : _intOrderItemsFull!;
    final showItemsCount = forCustomer
        ? _custOrderItemsCount!
        : _intOrderItemsCount!;
    final showPayment = forCustomer ? _custPayment! : _intPayment!;

    // ===== Order Details =====
    if (showDetails) {
      final logoPath = prefs.getString('receiptLogoPath')?.trim() ?? '';
      if (logoPath.isNotEmpty) {
        final logoFile = File(logoPath);
        if (await logoFile.exists()) {
          try {
            final raw = await logoFile.readAsBytes();
            final decoded = im.decodeImage(raw);
            if (decoded != null) {
              final img = _centerReceiptLogoOnSlipWidth(
                _resizeImageToReceiptLogoBox(decoded),
              );
              bytes += generator.image(img, align: PosAlign.center);
              bytes += generator.feed(1);
            }
          } catch (_) {
            // Invalid or unreadable logo file — continue without image.
          }
        }
      }
      bytes += _slipCenteredTextRow(
        generator,
        shopName,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
        ),
      );
      bytes += _slipCenteredTextRow(generator, 'Order #: ${order.orderNumber}');
      bytes += _slipCenteredTextRow(generator, 'Date: ${order.dateTime}');
      bytes += _slipCenteredTextRow(
        generator,
        forCustomer ? 'Order Slip: For Customer' : 'Order Slip: For Kitchen',
      );
      if (order.isCashOnDelivery) {
        bytes += _slipCenteredTextRow(
          generator,
          'Customer: ${order.customerDetails}',
        );
        bytes += _slipCenteredTextRow(generator, 'Order Type: Home Delivery');
      }
      bytes += generator.hr();
    }

    // ===== Item List (raster: supports Urdu / Arabic product names) =====
    if (showItemsFull) {
      im.Image? itemListImage;
      try {
        final rows = <SlipItemRow>[
          for (final item in items)
            SlipItemRow(
              name: _getProductById(item.productId).name,
              quantity: item.quantity,
              unitPrice: item.price,
              lineTotal: item.quantity * item.price,
            ),
        ];
        final raw = await rasterItemListSection(rows: rows);
        if (raw != null) {
          itemListImage = _normalizeSlipRasterWidth(raw);
        }
      } catch (_) {
        itemListImage = null;
      }
      if (itemListImage != null) {
        bytes += generator.image(itemListImage, align: PosAlign.center);
        bytes += generator.feed(1);
      } else {
        bytes += generator.row([
          PosColumn(
            text: 'Item',
            width: 4,
            styles: const PosStyles(bold: true),
          ),
          PosColumn(
            text: 'Qty',
            width: 2,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
          PosColumn(
            text: 'Price',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
          PosColumn(
            text: 'Total',
            width: 3,
            styles: const PosStyles(bold: true, align: PosAlign.right),
          ),
        ]);
        bytes += generator.hr(ch: '-');
        for (var item in items) {
          final name = _getProductById(item.productId).name;
          final qty = item.quantity;
          final unit = item.price;
          final lineTotal = qty * unit;

          bytes += generator.row([
            PosColumn(text: _slipShortName(name, 8), width: 4),
            PosColumn(
              text: '$qty',
              width: 2,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: unit.toStringAsFixed(0),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
            PosColumn(
              text: lineTotal.toStringAsFixed(0),
              width: 3,
              styles: const PosStyles(align: PosAlign.right),
            ),
          ]);
        }
      }
      bytes += generator.hr();
    }

    // ===== Item count (raster; kitchen: by component product, deals expanded) =====
    if (showItemsCount) {
      final kitchen = _kitchenCountsByProductId(items);
      final sortedIds = kitchen.keys.toList()
        ..sort(
          (a, b) => _getProductById(
            a,
          ).name.toLowerCase().compareTo(_getProductById(b).name.toLowerCase()),
        );
      im.Image? countImage;
      try {
        final lines = <SlipCountLine>[
          for (final id in sortedIds)
            SlipCountLine(
              quantity: kitchen[id]!,
              productName: _getProductById(id).name,
            ),
        ];
        final raw = await rasterItemCountSection(lines: lines);
        if (raw != null) {
          countImage = _normalizeSlipRasterWidth(raw);
        }
      } catch (_) {
        countImage = null;
      }
      if (countImage != null) {
        bytes += generator.image(countImage, align: PosAlign.center);
        bytes += generator.feed(1);
      } else {
        for (final id in sortedIds) {
          final qty = kitchen[id]!;
          final name = _getProductById(id).name;
          bytes += generator.text('$qty x $name');
        }
      }
      bytes += generator.hr();
    }

    // ===== Payment =====
    if (showPayment) {
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true)),
        PosColumn(
          text: grandTotal.toStringAsFixed(0),
          width: 4,
          styles: const PosStyles(align: PosAlign.right, bold: true),
        ),
      ]);
      if (forCustomer) {
        bytes += generator.text(
          'Thank you for ordering!',
          styles: const PosStyles(align: PosAlign.center),
        );
      }
    }

    bytes += generator.cut();
    return bytes;
  }

  /// Sends raw ESC/POS bytes to the printer over TCP (port 9100).
  Future<void> printSlip(List<int> bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final host = (prefs.getString('printerIp') ?? '192.168.0.100').trim();
    if (host.isEmpty) {
      throw const FormatException('Printer IP is not set');
    }
    const rawPort = 9100;
    final socket = await Socket.connect(
      host,
      rawPort,
      timeout: const Duration(seconds: 12),
    );
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}
