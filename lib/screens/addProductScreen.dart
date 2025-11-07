import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../widgets/dbHelper.dart';

class AddProductScreen extends StatefulWidget {
  final VoidCallback onSave;
  final Product? product;

  AddProductScreen({required this.onSave, this.product});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final DbHelper _dbHelper = DbHelper();
  final _formKey = GlobalKey<FormState>();

  double totalPrice = 0.0;
  String _name = '';
  double _price = 0.0;
  String _info = '';
  bool _isDeal = false;

  List<Product> _allNonDealProducts = []; // all products
  List<Product> _filteredProducts = []; // products filtered by category
  List<int> _selectedProductsId = [];

  List<Category> _categories = [];
  int? _selectedCategoryId; // for product itself
  int? _selectedDealCategoryId; // for filtering deals

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _name = widget.product!.name;
      _price = widget.product!.price;
      _info = widget.product!.info;
      _isDeal = widget.product!.isDeal;
      if (_isDeal && widget.product!.productList != null) {
        _selectedProductsId.addAll(widget.product!.productList!);
      }
    }
    if (_isDeal) {
      _fetchNonDealProducts();
      _fetchCategories();
    }
  }

  Future<void> _fetchNonDealProducts() async {
    final prods = await _dbHelper.getNonDealProducts();
    setState(() {
      _allNonDealProducts = prods.reversed.toList();
      // Precalculate total price if editing
      for (var id in _selectedProductsId) {
        final p = _allNonDealProducts.firstWhere(
          (e) => e.id == id,
          orElse: () => Product(categoryId: 0, name: '', price: 0, info: ''),
        );
        if (p.id != null) totalPrice += p.price;
      }
    });
  }

  Future<void> _fetchCategories() async {
    final cats = await _dbHelper.getCategories();
    final categoryIdsWithProducts = _allNonDealProducts.map((p) => p.categoryId).toSet();
    final filteredCats = cats.where((c) => categoryIdsWithProducts.contains(c.id)).toList();
    _categories = [
      Category(id: -1, name: 'Selected'),
      ...filteredCats.reversed.toList()
    ];
    _selectedCategoryId = _categories.first.id;
    if (_categories.isNotEmpty) {
      _selectedDealCategoryId = _selectedCategoryId; // default first category
      _filterDealProducts();
    }
    setState(() {
    });
  }

  void _filterDealProducts() {
    if (_selectedDealCategoryId == -1) {
      _filteredProducts = _allNonDealProducts
          .where((p) => _selectedProductsId.contains(p.id))
          .toList();
    } else {
      _filteredProducts = _allNonDealProducts
          .where((p) => p.categoryId == _selectedDealCategoryId)
          .toList();
    }
    setState(() {});
  }

  void _updateTotal(double price, bool add) {
    setState(() => totalPrice += add ? price : -price);
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final product = Product(
        id: widget.product?.id,
        name: _name,
        categoryId: _selectedCategoryId!,
        price: _price,
        info: _info,
        isDeal: _isDeal,
        productList: _isDeal ? _selectedProductsId : null,
      );
      if (widget.product == null) {
        await _dbHelper.insertProduct(product);
      } else {
        await _dbHelper.updateProduct(product);
      }
      widget.onSave();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Item' : 'Edit Item'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Enter item name' : null,
                onSaved: (v) => _name = v!,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                decoration: const InputDecoration(
                  labelText: 'Select Category',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) => v == null ? 'Please select category' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _price.toString(),
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
                onSaved: (v) => _price = double.parse(v!),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _info,
                decoration: const InputDecoration(
                  labelText: 'Info',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                onSaved: (v) => _info = v ?? '',
              ),
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  title: const Text(
                    'Is Deal',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Enable to create a deal package'),
                  value: _isDeal,
                  onChanged: (value) {
                    setState(() {
                      _isDeal = value;
                      if (value) _fetchNonDealProducts();
                    });
                  },
                ),
              ),
              if (_isDeal) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Deal Configuration',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 40,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _categories.length,
                            itemBuilder: (ctx, index) {
                              final cat = _categories[index];
                              final isSelected =
                                  cat.id == _selectedDealCategoryId;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 3,
                                ),
                                child: ChoiceChip(
                                  label: Text(cat.name),
                                  selected: isSelected,
                                  onSelected: (_) {
                                    setState(() {
                                      _selectedDealCategoryId = cat.id;
                                      _filterDealProducts();
                                    });
                                  },
                                  selectedColor: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                  backgroundColor: Colors.grey[200],
                                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Deal Total:',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '${_selectedProductsId.length} items - Rs. ${totalPrice.toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.inventory,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Select Items for Deal',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4, // Fixed height for scrolling
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (ctx, index) {
                            final product = _filteredProducts[index];
                            final count = _selectedProductsId
                                .where((id) => id == product.id)
                                .length;

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                title: Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  'Rs. ${product.price.toStringAsFixed(0)}',
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
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
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                        onPressed: count > 0
                                            ? () {
                                                setState(() {
                                                  _selectedProductsId.remove(
                                                    product.id,
                                                  );
                                                  _updateTotal(
                                                    product.price,
                                                    false,
                                                  );
                                                });
                                              }
                                            : null,
                                        color: count > 0
                                            ? Colors.red[600]
                                            : Colors.grey[400],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        child: Text(
                                          '$count',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _selectedProductsId.add(
                                              product.id!,
                                            );
                                            _updateTotal(product.price, true);
                                          });
                                        },
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.primary,
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
                  ),
                ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  widget.product == null ? 'Save Item' : 'Update Item',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
