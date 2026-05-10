import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/salesReportScreen.dart';
import '../widgets/dropdownField.dart';
import '../screens/settingsScreen.dart';
import '../screens/backupScreen.dart';
import '../utils/app_colors.dart';

class PrinterSettingsScreen extends StatefulWidget {
  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLoading;
  String _storeName = "My Store";
  String _selectedHour = '09';
  String _selectedMinute = '00';
  String _selectedAmPm = 'AM';

  final List<String> _hours = List.generate(
    12,
    (index) => (index + 1).toString().padLeft(2, '0'),
  );
  final List<String> _minutes = List.generate(
    60,
    (index) => index.toString().padLeft(2, '0'),
  );
  final List<String> _amPm = ['AM', 'PM'];

  bool _enableDelete = false;
  String _appLetter = 'A';
  int _orderNoMaxLength = 4;

  final List<String> _letters = List.generate(
    26,
    (i) => String.fromCharCode(65 + i),
  );
  final List<String> _orderLengthOptions = ['3', '4', '5', '6'];

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _storeName = prefs.getString('storeName') ?? "My Store";
    String savedTime =
        prefs.getString('timeLimit') ??
        '$_selectedHour:$_selectedMinute $_selectedAmPm';
    List<String> timeParts = savedTime.split(RegExp(r'[: ]'));
    _selectedHour = timeParts[0].padLeft(2, '0');
    _selectedMinute = timeParts[1].padLeft(2, '0');
    _selectedAmPm = timeParts[2];

    _enableDelete = prefs.getBool('enableDelete') ?? false;
    _appLetter = prefs.getString('appLetter') ?? 'A';
    _orderNoMaxLength = prefs.getInt('orderNoMaxLength') ?? 4;

    Timer(const Duration(milliseconds: 300), () {
      setState(() => _isLoading = false);
    });
  }

  Future<void> _setSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeName', _storeName);
    await prefs.setString(
      'timeLimit',
      '$_selectedHour:$_selectedMinute $_selectedAmPm',
    );

    await prefs.setBool('enableDelete', _enableDelete);
    await prefs.setString('appLetter', _appLetter);
    await prefs.setInt('orderNoMaxLength', _orderNoMaxLength);
  }

  Future<void> _saveSettings() async {
    await _setSettings();
    _showDialog('Settings saved successfully!');
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _storeName = "My Store";
    _selectedHour = '09';
    _selectedMinute = '00';
    _selectedAmPm = 'AM';

    _enableDelete = false;
    _appLetter = 'A';
    _orderNoMaxLength = 4;

    await _setSettings();
    setState(() {
      _isLoading = false;
    });
    _showDialog('Settings reset to default successfully!');
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading settings...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Store Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Store Information',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: _storeName,
                      decoration: const InputDecoration(
                        labelText: 'Store Name',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => _storeName = val,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a store name';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // App Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'App Settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Delete Functionality'),
                      subtitle: const Text('Allow deletion of orders, products, and categories'),
                      value: _enableDelete,
                      onChanged: (val) {
                        setState(() => _enableDelete = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownField(
                            label: 'App Letter',
                            value: _appLetter,
                            items: _letters,
                            onChanged: (val) {
                              setState(() => _appLetter = val!);
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownField(
                            label: 'Order No Length',
                            value: _orderNoMaxLength.toString(),
                            items: _orderLengthOptions,
                            onChanged: (val) {
                              setState(() => _orderNoMaxLength = int.parse(val!));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Time Settings Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Shift Time Settings',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownField(
                            label: 'Hour',
                            value: _selectedHour,
                            items: _hours,
                            onChanged: (value) {
                              setState(() {
                                _selectedHour = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownField(
                            label: 'Minute',
                            value: _selectedMinute,
                            items: _minutes,
                            onChanged: (value) {
                              setState(() {
                                _selectedMinute = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownField(
                            label: 'AM/PM',
                            value: _selectedAmPm,
                            items: _amPm,
                            onChanged: (value) {
                              setState(() {
                                _selectedAmPm = value!;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _saveSettings();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Save Settings'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _resetSettings();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFEFEFEF),
                      foregroundColor: AppColors.textPrimary,
                    ),
                    child: const Text('Reset Settings'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
