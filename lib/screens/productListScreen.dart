import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../widgets/add_new_fab.dart';
import '../widgets/dbHelper.dart';
import '../screens/addProductScreen.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';
import '../widgets/category_picker_tile.dart';
import '../utils/main_tab_index.dart';
import '../utils/local_image.dart';

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final DbHelper _dbHelper = DbHelper();
  List<Category> _categories = [];
  int? _selectedCategoryId;
  List<Product> _products = [];
  bool _canDelete = false;

  void _onProductsTabVisible() {
    if (mainTabIndex.value == 1 && mounted) {
      _refreshProducts();
    }
  }

  @override
  void initState() {
    super.initState();
    mainTabIndex.addListener(_onProductsTabVisible);
    _fetchDelete();
    _fetchCategories();
    _fetchProducts();
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onProductsTabVisible);
    super.dispose();
  }

  Future<void> _fetchDelete() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _canDelete = prefs.getBool('enableDelete') ?? false;
    });
  }

  Future<void> _fetchCategories() async {
    final cats = await _dbHelper.getVisibleCategories();
    if (!mounted) return;
    setState(() {
      _categories = cats.reversed.toList();
      if (_selectedCategoryId != null &&
          !_categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = null;
      }
    });
  }

  Future<void> _fetchProducts() async {
    final products = await _dbHelper.getProductsInVisibleCategories();
    setState(() {
      _products = products;
    });
  }

  Future<void> _refreshProducts() async {
    await _fetchDelete();
    await _fetchCategories();
    await _fetchProducts();
  }

  Future<void> _deleteProduct(int id) async {
    await _dbHelper.deleteProduct(id);
    await _fetchProducts();
  }

  Future<void> _toggleProductVisible(Product product) async {
    await _dbHelper.updateProduct(
      product.copyWith(isVisible: !product.isVisible),
    );
    _fetchProducts();
  }

  String? _categoryImagePath(int? categoryId) {
    if (categoryId == null) return null;
    for (final c in _categories) {
      if (c.id == categoryId) return c.imagePath;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    var filtered = _products.toList();
    if (_selectedCategoryId != null) {
      filtered = filtered
          .where((p) => p.categoryId == _selectedCategoryId)
          .toList();
    }
    final filteredProducts = filtered.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProducts,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: categoryPickerListHeight,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalScreenPadding(context),
                      vertical: 8,
                    ),
                    itemCount: _categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return CategoryPickerTile(
                          label: 'All',
                          imagePath: null,
                          useListIcon: true,
                          selected: _selectedCategoryId == null,
                          onTap: () =>
                              setState(() => _selectedCategoryId = null),
                        );
                      }
                      final cat = _categories[index - 1];
                      return CategoryPickerTile(
                        label: cat.name,
                        imagePath: cat.imagePath,
                        selected: _selectedCategoryId == cat.id,
                        onTap: () =>
                            setState(() => _selectedCategoryId = cat.id),
                      );
                    },
                  ),
                ),
                const Divider(height: 1, thickness: 0.5),
                Expanded(
                  child: filteredProducts.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: EdgeInsets.fromLTRB(
                            horizontalScreenPadding(context),
                            8,
                            horizontalScreenPadding(context),
                            rootTabBodyBottomScrollPadding(context),
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount:
                                catalogGridCrossAxisCount(context),
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio:
                                catalogGridChildAspectRatio(context),
                          ),
                          itemCount: filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = filteredProducts[index];
                            return _wrapDismissible(
                              product,
                              _buildProductCard(product),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: AddNewFab(
        heroTag: 'fab_product_list',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddProductScreen(onSave: _fetchProducts),
            ),
          );
        },
      ),
    );
  }

  Widget _wrapDismissible(Product product, Widget child) {
    if (!_canDelete) return child;
    return Dismissible(
      key: ValueKey('prod_${product.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: const Icon(
          Icons.delete_forever,
          color: AppColors.error,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: const Text('Delete Product'),
              content: const Text(
                'Are you sure you want to delete this product?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
            false;
      },
      onDismissed: (direction) async {
        try {
          await _deleteProduct(product.id!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Delete failed: $e')),
            );
            await _fetchProducts();
          }
        }
      },
      child: child,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Products Found',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a product to get started.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * value),
          child: Opacity(
            opacity: value * (product.isVisible ? 1.0 : 0.55),
            child: Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
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
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LocalOrAssetImage(
                                path: product.imagePath,
                                fallbackPath: _categoryImagePath(product.categoryId),
                                entity: LocalImageEntity.product,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: Material(
                                color: context.colorScheme.surface.withValues(
                                  alpha: 0.92,
                                ),
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: IconButton(
                                  tooltip: product.isVisible
                                      ? 'Hide from catalog'
                                      : 'Show in catalog',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  iconSize: 20,
                                  onPressed: () => _toggleProductVisible(product),
                                  icon: Icon(
                                    product.isVisible
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: product.isVisible
                                        ? AppColors.primary
                                        : context.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      if (product.info.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          product.info,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Rs. ${product.price.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                ),
                          ),
                        ),
                      ),
                      if (product.isDeal) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.local_offer,
                              size: 14,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Deal package',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
