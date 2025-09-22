import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/dropdownField.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLoading;
  String _selectedHour = '09';
  String _selectedMinute = '00';
  String _selectedAmPm = 'AM';

  final List<String> _hours =
      List.generate(12, (index) => (index + 1).toString().padLeft(2, '0'));
  final List<String> _minutes =
      List.generate(60, (index) => index.toString().padLeft(2, '0'));
  final List<String> _amPm = ['AM', 'PM'];

  // Printing Settings
  bool _customerSlipEnabled = false;
  bool _internalSlipEnabled = false;

  // Sections
  bool _custOrderDetails = true;
  bool _custOrderItemsFull = true;
  bool _custOrderItemsCount = false;
  bool _custPayment = true;

  bool _intOrderDetails = true;
  bool _intOrderItemsFull = false;
  bool _intOrderItemsCount = true;
  bool _intPayment = true;

  @override
  void initState() {
    super.initState();
    _isLoading = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    String savedTime = prefs.getString('timeLimit') ??
        '$_selectedHour:$_selectedMinute $_selectedAmPm';
    List<String> timeParts = savedTime.split(RegExp(r'[: ]'));
    _selectedHour = timeParts[0].padLeft(2, '0');
    _selectedMinute = timeParts[1].padLeft(2, '0');
    _selectedAmPm = timeParts[2];

    // Printing
    _customerSlipEnabled = prefs.getBool('customerSlipEnabled') ?? false;
    _internalSlipEnabled = prefs.getBool('internalSlipEnabled') ?? false;

    _custOrderDetails = prefs.getBool('custOrderDetails') ?? true;
    _custOrderItemsFull = prefs.getBool('custOrderItemsFull') ?? true;
    _custOrderItemsCount = prefs.getBool('custOrderItemsCount') ?? false;
    _custPayment = prefs.getBool('custPayment') ?? true;

    _intOrderDetails = prefs.getBool('intOrderDetails') ?? true;
    _intOrderItemsFull = prefs.getBool('intOrderItemsFull') ?? false;
    _intOrderItemsCount = prefs.getBool('intOrderItemsCount') ?? true;
    _intPayment = prefs.getBool('intPayment') ?? true;

    Timer(const Duration(milliseconds: 300), () {
      setState(() => _isLoading = false);
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'timeLimit', '$_selectedHour:$_selectedMinute $_selectedAmPm');

    // Printing
    await prefs.setBool('customerSlipEnabled', _customerSlipEnabled);
    await prefs.setBool('internalSlipEnabled', _internalSlipEnabled);

    await prefs.setBool('custOrderDetails', _custOrderDetails);
    await prefs.setBool('custOrderItemsFull', _custOrderItemsFull);
    await prefs.setBool('custOrderItemsCount', _custOrderItemsCount);
    await prefs.setBool('custPayment', _custPayment);

    await prefs.setBool('intOrderDetails', _intOrderDetails);
    await prefs.setBool('intOrderItemsFull', _intOrderItemsFull);
    await prefs.setBool('intOrderItemsCount', _intOrderItemsCount);
    await prefs.setBool('intPayment', _intPayment);

    _showDialog('Settings saved successfully!');
  }

  Future<void> _resetSettings() async {
    _selectedHour = '09';
    _selectedMinute = '00';
    _selectedAmPm = 'AM';

    _customerSlipEnabled = false;
    _internalSlipEnabled = false;

    _custOrderDetails = true;
    _custOrderItemsFull = true;
    _custOrderItemsCount = false;
    _custPayment = true;

    _intOrderDetails = true;
    _intOrderItemsFull = false;
    _intOrderItemsCount = true;
    _intPayment = true;

    await _saveSettings();
    _showDialog('Settings reset to default successfully!');
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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

  Widget _buildSlipSection({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onEnableChanged,
    required List<Widget> children,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ExpansionTile(
        title: SwitchListTile(
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          value: enabled,
          onChanged: onEnableChanged,
        ),
        children: enabled ? children : [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DropdownField(
                    label: 'Hour',
                    value: _selectedHour,
                    items: _hours,
                    onChanged: (value) {
                      setState(() {
                        _selectedHour = value!;
                      });
                    },
                  ),
                  DropdownField(
                    label: 'Minute',
                    value: _selectedMinute,
                    items: _minutes,
                    onChanged: (value) {
                      setState(() {
                        _selectedMinute = value!;
                      });
                    },
                  ),
                  DropdownField(
                    label: 'AM/PM',
                    value: _selectedAmPm,
                    items: _amPm,
                    onChanged: (value) {
                      setState(() {
                        _selectedAmPm = value!;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Customer Slip Section
              _buildSlipSection(
                title: 'Customer Slip',
                enabled: _customerSlipEnabled,
                onEnableChanged: (val) =>
                    setState(() => _customerSlipEnabled = val),
                children: [
                  CheckboxListTile(
                    title: const Text('Order Details'),
                    value: _custOrderDetails,
                    onChanged: (v) => setState(() => _custOrderDetails = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Order Items (Full)'),
                    value: _custOrderItemsFull,
                    onChanged: (v) => setState(() => _custOrderItemsFull = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Order Items (Count)'),
                    value: _custOrderItemsCount,
                    onChanged: (v) => setState(() => _custOrderItemsCount = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Payment'),
                    value: _custPayment,
                    onChanged: (v) => setState(() => _custPayment = v!),
                  ),
                ],
              ),
              // Internal Slip Section
              _buildSlipSection(
                title: 'Internal Slip',
                enabled: _internalSlipEnabled,
                onEnableChanged: (val) =>
                    setState(() => _internalSlipEnabled = val),
                children: [
                  CheckboxListTile(
                    title: const Text('Order Details'),
                    value: _intOrderDetails,
                    onChanged: (v) => setState(() => _intOrderDetails = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Order Items (Full)'),
                    value: _intOrderItemsFull,
                    onChanged: (v) => setState(() => _intOrderItemsFull = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Order Items (Count)'),
                    value: _intOrderItemsCount,
                    onChanged: (v) => setState(() => _intOrderItemsCount = v!),
                  ),
                  CheckboxListTile(
                    title: const Text('Payment'),
                    value: _intPayment,
                    onChanged: (v) => setState(() => _intPayment = v!),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _formKey.currentState!.save();
                        _saveSettings();
                      }
                    },
                    child: const Text('Save Settings'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                      });
                      _resetSettings();
                    },
                    child: const Text('Reset Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
