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

  List<Product> _allNonDealProducts = [];    // all products
  List<Product> _filteredProducts = [];      // products filtered by category
  List<int> _selectedProductsId = [];

  List<Category> _categories = [];
  int? _selectedCategoryId;                  // for product itself
  int? _selectedDealCategoryId;              // for filtering deals

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
    _fetchCategories();
    if (_isDeal) _fetchNonDealProducts();
  }

  Future<void> _fetchCategories() async {
    final cats = await _dbHelper.getCategories();
    setState(() {
      _categories = cats.reversed.toList();
      if (widget.product != null) {
        _selectedCategoryId = widget.product!.categoryId;
      }
    });
  }

  Future<void> _fetchNonDealProducts() async {
    final prods = await _dbHelper.getNonDealProducts();
    setState(() {
      _allNonDealProducts = prods.reversed.toList();
      if (_categories.isNotEmpty) {
        _selectedDealCategoryId ??= _categories.first.id; // default first category
        _filterDealProducts();
      }
      // Precalculate total price if editing
      for (var id in _selectedProductsId) {
        final p = _allNonDealProducts.firstWhere((e) => e.id == id, orElse: () => Product(categoryId: 0, name: '', price: 0, info: ''));
        if (p.id != null) totalPrice += p.price;
      }
    });
  }

  void _filterDealProducts() {
    setState(() {
      _filteredProducts = _allNonDealProducts
          .where((p) => p.categoryId == _selectedDealCategoryId)
          .toList();
    });
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
      appBar: AppBar(title: Text(widget.product == null ? 'Add Item' : 'Edit Item')),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator: (v) => v == null || v.isEmpty ? 'Enter item name' : null,
                onSaved: (v) => _name = v!,
              ),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                items: _categories
                    .map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategoryId = v),
                decoration: const InputDecoration(labelText: 'Select Category'),
                validator: (v) => v == null ? 'Please select category' : null,
              ),
              TextFormField(
                initialValue: _price.toString(),
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.isEmpty ? 'Enter price' : null,
                onSaved: (v) => _price = double.parse(v!),
              ),
              TextFormField(
                initialValue: _info,
                decoration: const InputDecoration(labelText: 'Info'),
                onSaved: (v) => _info = v ?? '',
              ),
              SwitchListTile(
                title: const Text('Is Deal'),
                value: _isDeal,
                onChanged: (value) {
                  setState(() {
                    _isDeal = value;
                    if (value) _fetchNonDealProducts();
                  });
                },
              ),
              if (_isDeal) ...[
                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (ctx, index) {
                      final cat = _categories[index];
                      final isSelected = cat.id == _selectedDealCategoryId;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDealCategoryId = cat.id;
                            _filterDealProducts();
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(cat.name,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.bold,
                                )),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Items for Deal',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: [
                        Text('${_selectedProductsId.length} x ',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('Rs. ${totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),

                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: ListView.builder(
                      itemCount: _filteredProducts.length,
                      itemBuilder: (ctx, index) {
                        final product = _filteredProducts[index];
                        final count = _selectedProductsId
                            .where((id) => id == product.id)
                            .length;

                        return ListTile(
                          title: Text(product.name),
                          subtitle: Text('Rs. ${product.price.toStringAsFixed(0)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: count > 0
                                    ? () {
                                        setState(() {
                                          _selectedProductsId.remove(product.id);
                                          _updateTotal(product.price, false);
                                        });
                                      }
                                    : null,
                              ),
                              Text('$count'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  setState(() {
                                    _selectedProductsId.add(product.id!);
                                    _updateTotal(product.price, true);
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(widget.product == null ? 'Save Item' : 'Update Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
