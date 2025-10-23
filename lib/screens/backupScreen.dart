import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../widgets/dbHelper.dart';
import '../screens/settingsScreen.dart';
import '../screens/printerSettingsScreen.dart';

class BackupScreen extends StatelessWidget {
  DbHelper _dbHelper = DbHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export Data'),
              onPressed: () async {
                await _dbHelper.exportBackup();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup exported successfully')),
                );
              },
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              icon: const Icon(Icons.upload),
              label: const Text('Import Data'),
              onPressed: () async {
                await _dbHelper.importBackup();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Backup imported successfully')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
