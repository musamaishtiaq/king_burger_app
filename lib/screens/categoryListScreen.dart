import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../screens/addCategoryScreen.dart';
import '../utils/app_colors.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/main_tab_index.dart';
import '../utils/local_image.dart';
import '../widgets/dbHelper.dart';

class CategoryListScreen extends StatefulWidget {
  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  final DbHelper _dbHelper = DbHelper();
  List<Category> _categories = [];
  bool _canDelete = false;

  void _onCategoryTabVisible() {
    if (mainTabIndex.value == 2 && mounted) {
      _refreshCategories();
    }
  }

  @override
  void initState() {
    super.initState();
    mainTabIndex.addListener(_onCategoryTabVisible);
    _refreshCategories();
  }

  @override
  void dispose() {
    mainTabIndex.removeListener(_onCategoryTabVisible);
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
    final categories = await _dbHelper.getCategories();
    setState(() {
      _categories = categories.reversed.toList();
    });
  }

  Future<void> _refreshCategories() async {
    await _fetchDelete();
    await _fetchCategories();
  }

  Future<void> _deleteCategory(int id) async {
    await _dbHelper.deleteCategory(id);
    await _fetchCategories();
  }

  Future<void> _toggleCategoryVisible(Category category) async {
    await _dbHelper.updateCategory(
      category.copyWith(isVisible: !category.isVisible),
    );
    _fetchCategories();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCategories,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
            child: filteredCategories.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      horizontalScreenPadding(context),
                      8,
                      horizontalScreenPadding(context),
                      rootTabBodyBottomScrollPadding(context),
                    ),
                    itemCount: filteredCategories.length,
                    itemBuilder: (context, index) {
                      final category = filteredCategories[index];
                      final tile = _buildCategoryTile(category);
                      if (_canDelete) {
                        return Dismissible(
                          key: ValueKey('cat_${category.id}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 8),
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
                                  title: const Text('Delete Category'),
                                  content: const Text(
                                    'Are you sure you want to delete this category?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
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
                              await _deleteCategory(category.id!);
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Delete failed: $e')),
                                );
                                await _fetchCategories();
                              }
                            }
                          },
                          child: tile,
                        );
                      }
                      return tile;
                    },
                  ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_category_list',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddCategoryScreen(onSave: _fetchCategories),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryTile(Category category) {
    return Opacity(
      opacity: category.isVisible ? 1 : 0.55,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 64,
              height: 64,
              child: LocalOrAssetImage(
                path: category.imagePath,
                entity: LocalImageEntity.category,
                fit: BoxFit.cover,
              ),
            ),
          ),
          title: Text(
            category.name,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          subtitle: category.isVisible
              ? null
              : Text(
                  'Hidden from order catalog',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: category.isVisible ? 'Hide from catalog' : 'Show in catalog',
                onPressed: () => _toggleCategoryVisible(category),
                icon: Icon(
                  category.isVisible ? Icons.visibility : Icons.visibility_off,
                  color: category.isVisible
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddCategoryScreen(
                  category: category,
                  onSave: _fetchCategories,
                ),
              ),
            );
          },
        ),
      ),
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
                Icons.category_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Categories Found',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Add a category to get started.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
