import 'package:flutter/material.dart';

import '../models/category.dart';
import '../widgets/dbHelper.dart';

class AddCategoryScreen extends StatefulWidget {
  final VoidCallback onSave;
  final Category? category;

  AddCategoryScreen({required this.onSave, this.category});

  @override
  _AddCategoryScreenState createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  DbHelper _dbHelper = DbHelper();
  final _formKey = GlobalKey<FormState>();
  final _nameFocusNode = FocusNode();
  String _name = '';

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _name = widget.category!.name;
    }
  }

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      final category = Category(
        id: widget.category?.id,
        name: _name,
      );
      if (widget.category == null) {
        print("-----Add Category-----");
        print(category.toString());
        await _dbHelper.insertCategory(category);
      } else {
        print("-----Update Category-----");
        print(category.toString());
        await _dbHelper.updateCategory(category);
      }
      widget.onSave();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [              
              TextFormField(
                focusNode: _nameFocusNode,
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Category Name'),
                textInputAction: TextInputAction.next,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a category name';
                  }
                  return null;
                },
                onSaved: (value) {
                  _name = value!;
                },
              ),
              const SizedBox(height: 15),
              ElevatedButton(
                onPressed: _saveForm,
                child: Text(
                    widget.category == null ? 'Save Category' : 'Update Category'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
