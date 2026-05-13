import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/category.dart';
import '../utils/local_image.dart';
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
  String? _pickedImagePath;
  bool _clearImage = false;

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _name = widget.category!.name;
    }
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

  Future<void> _saveForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      if (widget.category == null) {
        final category = Category(name: _name);
        final id = await _dbHelper.insertCategory(category);
        if (!_clearImage && _pickedImagePath != null) {
          final stored = await _dbHelper.storeEntityImage(
            _pickedImagePath!,
            'categories',
            id,
          );
          await _dbHelper.updateCategory(
            Category(id: id, name: _name, imagePath: stored),
          );
        }
      } else {
        String? imagePath = widget.category!.imagePath;
        if (_pickedImagePath != null) {
          imagePath = await _dbHelper.storeEntityImage(
            _pickedImagePath!,
            'categories',
            widget.category!.id!,
          );
        } else if (_clearImage) {
          imagePath = null;
        }
        final category = Category(
          id: widget.category!.id,
          name: _name,
          imagePath: imagePath,
          isVisible: widget.category!.isVisible,
        );
        await _dbHelper.updateCategory(category);
      }
      widget.onSave();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayPath =
        _clearImage ? null : (_pickedImagePath ?? widget.category?.imagePath);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Add Category' : 'Edit Category'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: LocalOrAssetImage(
                    path: displayPath,
                    entity: LocalImageEntity.category,
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
                  if (displayPath != null ||
                      widget.category?.imagePath != null) ...[
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
                focusNode: _nameFocusNode,
                initialValue: _name,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                textInputAction: TextInputAction.done,
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saveForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  widget.category == null ? 'Save Category' : 'Update Category',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
