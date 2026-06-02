import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/local_image.dart';
import '../widgets/category_picker_tile.dart';
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

  List<Category> _productLineCategories = [];
  List<Category> _dealChipCategories = [];
  int? _selectedCategoryId;
  int? _selectedDealCategoryId;
  String? _pickedImagePath;
  bool _clearImage = false;

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
    _loadProductCategories().then((_) {
      if (_isDeal) {
        _fetchNonDealProducts().then((_) => _fetchDealCategories());
      }
    });
  }

  Future<void> _loadProductCategories() async {
    final visible = await _dbHelper.getVisibleCategories();
    var list = visible.reversed.toList();
    if (widget.product != null) {
      final cid = widget.product!.categoryId;
      final hasCurrent = list.any((c) => c.id == cid);
      if (!hasCurrent) {
        final current = await _dbHelper.getCategory(cid);
        if (current != null) {
          list = [...list, current];
        }
      }
      _selectedCategoryId = cid;
    } else if (list.isNotEmpty) {
      _selectedCategoryId = list.first.id;
    } else {
      _selectedCategoryId = null;
    }
    if (!mounted) return;
    setState(() => _productLineCategories = list);
  }

  Future<void> _fetchNonDealProducts() async {
    final prods = await _dbHelper.getNonDealProducts();
    setState(() {
      _allNonDealProducts = prods;
      // Precalculate total price if editing
      for (var id in _selectedProductsId) {
        final p = _allNonDealProducts.firstWhere(
          (e) => e.id == id,
          orElse: () =>
            Product(categoryId: 0, name: '', price: 0, info: '', imagePath: null),
        );
        if (p.id != null) totalPrice += p.price;
      }
    });
  }

  Future<void> _fetchDealCategories() async {
    final cats = await _dbHelper.getVisibleCategories();
    final categoryIdsWithProducts =
        _allNonDealProducts.map((p) => p.categoryId).toSet();
    final filteredCats =
        cats.where((c) => categoryIdsWithProducts.contains(c.id)).toList();
    _dealChipCategories = [
      Category(id: -1, name: 'Selected'),
      ...filteredCats.reversed.toList()
    ];
    if (_dealChipCategories.isNotEmpty) {
      _selectedDealCategoryId = _dealChipCategories.first.id;
      _filterDealProducts();
    }
    setState(() {});
  }

  Future<void> _pickImage() async {
    final result =
        await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    setState(() {
      _pickedImagePath = result.files.single.path;
      _clearImage = false;
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

  String? _categoryImagePathForId(int? categoryId) {
    if (categoryId == null) return null;
    for (final c in _productLineCategories) {
      if (c.id == categoryId) return c.imagePath;
    }
    for (final c in _dealChipCategories) {
      if (c.id == categoryId) return c.imagePath;
    }
    return null;
  }

  String? _categoryImagePathForProduct(Product p) {
    return _categoryImagePathForId(p.categoryId);
  }

  void _updateTotal(double price, bool add) {
    setState(() => totalPrice += add ? price : -price);
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (widget.product == null) {
      final id = await _dbHelper.insertProduct(
        Product(
          name: _name,
          categoryId: _selectedCategoryId!,
          price: _price,
          info: _info,
          isDeal: _isDeal,
          productList: _isDeal ? _selectedProductsId : null,
          imagePath: null,
          isVisible: true,
        ),
      );
      if (_pickedImagePath != null) {
        final stored = await _dbHelper.storeEntityImage(
          _pickedImagePath!,
          'products',
          id,
        );
        await _dbHelper.updateProduct(
          Product(
            id: id,
            name: _name,
            categoryId: _selectedCategoryId!,
            price: _price,
            info: _info,
            isDeal: _isDeal,
            productList: _isDeal ? _selectedProductsId : null,
            imagePath: stored,
            isVisible: true,
          ),
        );
      }
    } else {
      String? imgPath = widget.product!.imagePath;
      if (_pickedImagePath != null) {
        imgPath = await _dbHelper.storeEntityImage(
          _pickedImagePath!,
          'products',
          widget.product!.id!,
        );
      } else if (_clearImage) {
        imgPath = null;
      }
      await _dbHelper.updateProduct(
        Product(
          id: widget.product!.id,
          name: _name,
          categoryId: _selectedCategoryId!,
          price: _price,
          info: _info,
          isDeal: _isDeal,
          productList: _isDeal ? _selectedProductsId : null,
          imagePath: imgPath,
          isVisible: widget.product!.isVisible,
        ),
      );
    }
    widget.onSave();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Item' : 'Edit Item'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LocalOrAssetImage(
                    path: _clearImage
                        ? null
                        : (_pickedImagePath ?? widget.product?.imagePath),
                    fallbackPath: _clearImage
                        ? null
                        : _categoryImagePathForId(
                            _selectedCategoryId ?? widget.product?.categoryId,
                          ),
                    entity: LocalImageEntity.product,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Choose image'),
                    ),
                  ),
                  if (!_clearImage &&
                      (_pickedImagePath != null ||
                          widget.product?.imagePath != null)) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Remove image',
                      onPressed: () => setState(() {
                        _clearImage = true;
                        _pickedImagePath = null;
                      }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Item Name',
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
                value: _selectedCategoryId,
                items: _productLineCategories
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
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                validator: (v) =>
                    v == null || _productLineCategories.isEmpty
                        ? 'Please select category'
                        : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: _price.toStringAsFixed(0),
                decoration: const InputDecoration(
                  labelText: 'Price',
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
                      if (value) {
                        _fetchNonDealProducts()
                            .then((_) => _fetchDealCategories());
                      }
                    });
                  },
                ),
              ),
              if (_isDeal) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.local_offer, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Deal package',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text(
                          '${_selectedProductsId.length} items · Rs. ${totalPrice.toStringAsFixed(0)}',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: math.min(
                    520.0,
                    MediaQuery.sizeOf(context).height * 0.52,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.extras.panelFill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        SizedBox(
                          height: categoryPickerListHeight,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            itemCount: _dealChipCategories.length,
                            itemBuilder: (context, index) {
                              final cat = _dealChipCategories[index];
                              final isSelectedChip = cat.id == -1;
                              return CategoryPickerTile(
                                label: cat.name,
                                imagePath: cat.imagePath,
                                useListIcon: isSelectedChip,
                                selected: _selectedDealCategoryId == cat.id,
                                onTap: () {
                                  setState(() {
                                    _selectedDealCategoryId = cat.id;
                                    _filterDealProducts();
                                  });
                                },
                              );
                            },
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5),
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount:
                                  catalogGridCrossAxisCount(context),
                              mainAxisSpacing: 8,
                              crossAxisSpacing: 8,
                              childAspectRatio:
                                  orderItemsGridChildAspectRatio(context),
                            ),
                            itemCount: _filteredProducts.length,
                            itemBuilder: (context, index) {
                              final product = _filteredProducts[index];
                              final count = _selectedProductsId
                                  .where((id) => id == product.id)
                                  .length;
                              return Card(
                                margin: EdgeInsets.zero,
                                clipBehavior: Clip.antiAlias,
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          child: LocalOrAssetImage(
                                            path: product.imagePath,
                                            fallbackPath:
                                                _categoryImagePathForProduct(
                                                    product),
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
                                          color: context.extras.chipFill,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.remove_circle_outline,
                                              ),
                                              onPressed: count > 0
                                                  ? () {
                                                      setState(() {
                                                        _selectedProductsId
                                                            .remove(
                                                                product.id);
                                                        _updateTotal(
                                                          product.price,
                                                          false,
                                                        );
                                                      });
                                                    }
                                                  : null,
                                              color: count > 0
                                                  ? AppColors.error
                                                  : AppColors.disabled,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            Text(
                                              '$count',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _selectedProductsId
                                                      .add(product.id!);
                                                  _updateTotal(
                                                    product.price,
                                                    true,
                                                  );
                                                });
                                              },
                                              color: AppColors.primary,
                                              visualDensity:
                                                  VisualDensity.compact,
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
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  widget.product == null ? 'Save Item' : 'Update Item',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
