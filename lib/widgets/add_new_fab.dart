import 'package:flutter/material.dart';

class AddNewFab extends StatelessWidget {
  final String heroTag;
  final VoidCallback onPressed;

  const AddNewFab({
    super.key,
    required this.heroTag,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      icon: const Icon(Icons.add),
      label: const Text('Add New'),
    );
  }
}
