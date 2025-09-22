import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../widgets/dbHelper.dart';
import '../screens/addProductScreen.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  DbHelper _dbHelper = DbHelper();
  List<Category> _categories = [];
  int? _selectedCategoryId;
  List<Product> _products = [];
  bool _showDeals = false;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _fetchProducts();
  }

  Future<void> _fetchCategories() async {
    final cats = await _dbHelper.getCategories();
    setState(() {
      _categories = cats.reversed.toList();
    });
  }

  Future<void> _fetchProducts() async {
    final products = await _dbHelper.getProducts();
    setState(() {
      _products = products.reversed.toList();
    });
  }

  Future<void> _refreshProducts() async {
    await _fetchProducts();
  }

  Future<void> _deleteProduct(int id) async {
    await _dbHelper.deleteProduct(id);
    _fetchProducts();
  }

  int _getItemQuantity(List<int>? productList, int productId) {
    return productList?.where((id) => id == productId).length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _products.where((p) => p.isDeal == _showDeals);
    if (_selectedCategoryId != null) {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId);
    }
    final filteredProducts = filtered.toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: _categories.length + 1,
                itemBuilder: (context, index) {
                  // index 0 = All
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
            const Divider(height: 1),
            Expanded(
              child: filteredProducts.isEmpty
                  ? const Center(child: Text('No products available'))
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return Dismissible(
                          key: Key(product.id.toString()),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_forever,
                                color: Colors.white),
                          ),
                          confirmDismiss: (direction) async {
                            return await showDialog(
                              context: context,
                              builder: (context) {
                                return AlertDialog(
                                  title: const Text('Confirm'),
                                  content: const Text('Delete this product?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          onDismissed: (direction) {
                            _deleteProduct(product.id!);
                          },
                          child: Container(
                            color: index % 2 == 0
                                ? Colors.grey[200]
                                : Colors.white,
                            child: ListTile(
                              title: Text(product.name),
                              subtitle: _showDeals
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Items in deal:'),
                                        ...product.productList
                                                ?.toSet()
                                                .map((id) {
                                              final item = _products.firstWhere(
                                                  (p) => p.id == id);
                                              return Text(
                                                  '${_getItemQuantity(product.productList, id)} x ${item.name}');
                                            }).toList() ??
                                            [],
                                      ],
                                    )
                                  : null,
                              trailing: Text(
                                  'Rs. ${product.price.toStringAsFixed(0)}'),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddProductScreen(
                                      product: product,
                                      onSave: _fetchProducts,
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddProductScreen(onSave: _fetchProducts)),
          );
        },
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showDeals = false;
                });
              },
              child: Text('Items'),
              style: ElevatedButton.styleFrom(
                backgroundColor: !_showDeals ? Colors.blue : Colors.grey,
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showDeals = true;
                });
              },
              child: Text('Deals'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _showDeals ? Colors.blue : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: Colors.blue,
        backgroundColor: Colors.grey[300],
        labelStyle: TextStyle(color: selected ? Colors.white : Colors.black),
      ),
    );
  }
}
