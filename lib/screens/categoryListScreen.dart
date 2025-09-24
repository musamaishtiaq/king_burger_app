import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/category.dart';
import '../widgets/dbHelper.dart';
import '../screens/addCategoryScreen.dart';

class CategoryListScreen extends StatefulWidget {
  @override
  _CategoryListScreenState createState() => _CategoryListScreenState();
}

class _CategoryListScreenState extends State<CategoryListScreen> {
  DbHelper _dbHelper = DbHelper();
  List<Category> _categories = [];
  bool? _canDelete;

  @override
  void initState() {
    super.initState();
    _fetchDelete();
    _fetchCategories();
  }

  Future<void> _fetchDelete() async {
    final prefs = await SharedPreferences.getInstance();
    _canDelete = prefs.getBool('enableDelete') ?? false;
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
    _fetchCategories();
  }

  int _getItemQuantity(List<int>? productList, int productId) {
    return productList?.where((id) => id == productId).length ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _categories.toList();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshCategories,
        child: filteredCategories.isEmpty
            ? const Center(child: Text('No categories available'))
            : ListView.builder(
                itemCount: filteredCategories.length,
                itemBuilder: (context, index) {
                  final category = filteredCategories[index];
                  return _canDelete!
                      ? Dismissible(
                          key: Key(category.id.toString()),
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
                                  content: const Text('Delete this category?'),
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
                            _deleteCategory(category.id!);
                          },
                          child: _buildCategoryTile(category, index),
                        )
                      : _buildCategoryTile(category, index);
                },
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) =>
                    AddCategoryScreen(onSave: _fetchCategories)),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCategoryTile(Category category, int index) {
    return Container(
      color: index % 2 == 0 ? Colors.grey[200] : Colors.white,
      child: ListTile(
        title: Text(category.name),
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
    );
  }
}
