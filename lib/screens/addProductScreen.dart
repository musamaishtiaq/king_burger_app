import 'package:flutter/material.dart';
import 'package:king_burger_app/models/category.dart';

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
  DbHelper _dbHelper = DbHelper();
  final _formKey = GlobalKey<FormState>();
  final _nameFocusNode = FocusNode();
  final _priceFocusNode = FocusNode();
  final _infoFocusNode = FocusNode();
  double totalPrice = 0.0;
  String _name = '';
  double _price = 0.0;
  String _info = '';
  bool _isDeal = false;
  List<Product> _nonDealProducts = [];
  List<int>? _selectedProductsId = [];
  List<Category> _categories = []; // from DB (id, name)
  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _name = widget.product!.name;
      _price = widget.product!.price;
      _info = widget.product!.info;
      _isDeal = widget.product!.isDeal;
      if (_isDeal && widget.product!.productList != null) {
        _selectedProductsId?.addAll(widget.product!.productList!);
      }
    }
    if (_isDeal) {
      _fetchNonDealProducts();
    }
    _fetchCategories();
  }

  Future<void> _fetchCategories() async {
    final categories = await _dbHelper.getCategories(); // return List<Map>
    setState(() {
      _categories = categories;
    });

    if (widget.product != null) {
      _selectedCategoryId = widget.product!.categoryId;
    }
  }

  Future<void> _fetchNonDealProducts() async {
    _nonDealProducts = await _dbHelper.getNonDealProducts();
    _nonDealProducts = _nonDealProducts.reversed.toList();

    for (var id in _selectedProductsId!) {
      final product =
          _nonDealProducts.firstWhere((product) => product.id == id);
      if (product != null) _totalPrice(product.price, true);
    }
  }

  Future<void> _totalPrice(double price, bool isAdded) async {
    setState(() {
      if (isAdded) {
        totalPrice += price;
      } else {
        totalPrice -= price;
      }
    });
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
        print("-----Add Product-----");
        print(product.toString());
        await _dbHelper.insertProduct(product);
      } else {
        print("-----Update Product-----");
        print(product.toString());
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
        title: Text(widget.product == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Is Deal'),
                value: _isDeal,
                onChanged: (value) {
                  setState(() {
                    _isDeal = value;
                    if (value) {
                      _fetchNonDealProducts();
                    }
                  });
                },
              ),
              if (_isDeal) ...[
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Items for Deal',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          Text(
                            '${_selectedProductsId!.length} x ',
                            style: const TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Rs. ${totalPrice.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ]),
                Expanded(
                  child: Container(
                    color: Colors.grey[200],
                    child: ListView.builder(
                        itemCount: _nonDealProducts.length,
                        itemBuilder: (context, index) {
                          final product = _nonDealProducts[index];
                          final existingProduct = _selectedProductsId!
                              .where((id) => id == product.id)
                              .length;

                          return ListTile(
                            title: Text(product.name),
                            subtitle:
                                Text(product.price.toStringAsFixed(0)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () {
                                    setState(() {
                                      if (_selectedProductsId != null &&
                                          existingProduct > 0) {
                                        _totalPrice(product.price, false);
                                        _selectedProductsId!.remove(product.id);
                                      }
                                    });
                                  },
                                ),
                                Text(existingProduct.toString() ?? '0'),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () {
                                    setState(() {
                                      _totalPrice(product.price, true);
                                      _selectedProductsId!.add(product.id!);
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                  ),
                ),
              ],
              TextFormField(
                focusNode: _nameFocusNode,
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Product Name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a product name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              DropdownButtonFormField<int>(
                value: _selectedCategoryId,
                items: _categories.map((cat) {
                  return DropdownMenuItem<int>(
                    value: cat.id as int,
                    child: Text(cat.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategoryId = value;
                  });
                },
                decoration: const InputDecoration(labelText: 'Select Category'),
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
                onSaved: (value) {
                  _selectedCategoryId = value;
                },
              ),
              TextFormField(
                focusNode: _priceFocusNode,
                initialValue: _price.toString(),
                decoration: const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a price';
                  }
                  return null;
                },
                onSaved: (value) {
                  _price = double.parse(value!);
                },
              ),
              TextFormField(
                focusNode: _infoFocusNode,
                initialValue: _info,
                decoration: const InputDecoration(labelText: 'Info'),
                textInputAction: TextInputAction.next,
                onSaved: (value) {
                  _info = value!;
                },
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(
                    widget.product == null ? 'Save Product' : 'Update Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
