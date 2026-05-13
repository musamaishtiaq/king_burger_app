import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/salesReportScreen.dart';
import '../widgets/dropdownField.dart';
import '../screens/printerSettingsScreen.dart';
import '../screens/backupScreen.dart';
import '../utils/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLoading;
  bool _customerSlipEnabled = false;
  bool _internalSlipEnabled = false;
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

  Future<void> _setSettings() async {
    final prefs = await SharedPreferences.getInstance();
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
  }

  Future<void> _saveSettings() async {
    await _setSettings();
    _showDialog('Settings saved successfully!');
  }

  Future<void> _resetSettings() async {
    final prefs = await SharedPreferences.getInstance();
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

  Widget _buildSlipSection({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool enabled,
    required ValueChanged<bool> onEnableChanged,
    required List<Widget> children,
  }) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            title: Row(
              children: [
                Icon(
                  icon,
                  color: enabled
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            value: enabled,
            onChanged: onEnableChanged,
          ),
          if (enabled) ...[const Divider(height: 1), ...children],
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      title: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Switch(value: value, onChanged: onChanged),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            // Header Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.print, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Receipt Printing Settings',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Configure what information to include on customer and kitchen receipts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Customer Slip Section
            _buildSlipSection(
              title: 'Customer Receipt',
              subtitle: 'Settings for customer-facing receipts',
              icon: Icons.receipt,
              enabled: _customerSlipEnabled,
              onEnableChanged: (val) =>
                  setState(() => _customerSlipEnabled = val),
              children: [
                _buildSettingTile(
                  title: 'Order Details',
                  subtitle: 'Include order number, date, and customer info',
                  value: _custOrderDetails,
                  onChanged: (v) => setState(() => _custOrderDetails = v!),
                ),
                _buildSettingTile(
                  title: 'Order Items (Full)',
                  subtitle: 'Show complete item details with prices',
                  value: _custOrderItemsFull,
                  onChanged: (v) => setState(() => _custOrderItemsFull = v!),
                ),
                _buildSettingTile(
                  title: 'Order Items (Count)',
                  subtitle: 'Show only item counts without details',
                  value: _custOrderItemsCount,
                  onChanged: (v) => setState(() => _custOrderItemsCount = v!),
                ),
                _buildSettingTile(
                  title: 'Payment Information',
                  subtitle: 'Include total amount and payment method',
                  value: _custPayment,
                  onChanged: (v) => setState(() => _custPayment = v!),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Kitchen receipt section
            _buildSlipSection(
              title: 'Kitchen Receipt',
              subtitle: 'Settings for kitchen / prep-line tickets',
              icon: Icons.restaurant_menu,
              enabled: _internalSlipEnabled,
              onEnableChanged: (val) =>
                  setState(() => _internalSlipEnabled = val),
              children: [
                _buildSettingTile(
                  title: 'Order Details',
                  subtitle: 'Include order number, date, and customer info',
                  value: _intOrderDetails,
                  onChanged: (v) => setState(() => _intOrderDetails = v!),
                ),
                _buildSettingTile(
                  title: 'Order Items (Full)',
                  subtitle: 'Show complete item details with prices',
                  value: _intOrderItemsFull,
                  onChanged: (v) => setState(() => _intOrderItemsFull = v!),
                ),
                _buildSettingTile(
                  title: 'Order Items (Count)',
                  subtitle: 'Show only item counts without details',
                  value: _intOrderItemsCount,
                  onChanged: (v) => setState(() => _intOrderItemsCount = v!),
                ),
                _buildSettingTile(
                  title: 'Payment Information',
                  subtitle: 'Include total amount and payment method',
                  value: _intPayment,
                  onChanged: (v) => setState(() => _intPayment = v!),
                ),
              ],
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}
