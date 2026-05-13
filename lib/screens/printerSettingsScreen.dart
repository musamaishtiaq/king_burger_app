import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/app_colors.dart';
import '../widgets/dropdownField.dart';

class PrinterSettingsScreen extends StatefulWidget {
  @override
  _PrinterSettingsScreenState createState() => _PrinterSettingsScreenState();
}

const String _defaultPrinterIp = '192.168.0.100';
const String _prefReceiptLogoPath = 'receiptLogoPath';

bool _isValidIpv4(String s) {
  final parts = s.trim().split('.');
  if (parts.length != 4) return false;
  for (final part in parts) {
    if (part.isEmpty) return false;
    final n = int.tryParse(part);
    if (n == null || n < 0 || n > 255) return false;
  }
  return true;
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLoading;
  String _storeName = "My Store";
  String? _receiptLogoPath;
  String _printerIp = _defaultPrinterIp;
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
    _printerIp = prefs.getString('printerIp') ?? _defaultPrinterIp;
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

    final logoPath = prefs.getString(_prefReceiptLogoPath)?.trim();
    if (logoPath != null && logoPath.isNotEmpty) {
      if (await File(logoPath).exists()) {
        _receiptLogoPath = logoPath;
      } else {
        await prefs.remove(_prefReceiptLogoPath);
        _receiptLogoPath = null;
      }
    } else {
      _receiptLogoPath = null;
    }

    Timer(const Duration(milliseconds: 300), () {
      setState(() => _isLoading = false);
    });
  }

  Future<void> _setSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('storeName', _storeName);
    await prefs.setString('printerIp', _printerIp.trim());
    await prefs.setString(
      'timeLimit',
      '$_selectedHour:$_selectedMinute $_selectedAmPm',
    );

    await prefs.setBool('enableDelete', _enableDelete);
    await prefs.setString('appLetter', _appLetter);
    await prefs.setInt('orderNoMaxLength', _orderNoMaxLength);

    final logo = _receiptLogoPath?.trim();
    if (logo == null || logo.isEmpty) {
      await prefs.remove(_prefReceiptLogoPath);
    } else {
      await prefs.setString(_prefReceiptLogoPath, logo);
    }
  }

  Future<void> _pickReceiptLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final src = File(path);
    if (!await src.exists()) return;

    final root = await getApplicationDocumentsDirectory();
    final ext = p.extension(path).toLowerCase();
    const allowed = {'.png', '.jpg', '.jpeg', '.gif', '.webp'};
    final safeExt = allowed.contains(ext) ? ext : '.png';
    final destPath = p.join(root.path, 'receipt_logo$safeExt');
    await src.copy(destPath);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefReceiptLogoPath, destPath);

    if (mounted) {
      setState(() => _receiptLogoPath = destPath);
    }
  }

  Future<void> _clearReceiptLogo() async {
    final path = _receiptLogoPath?.trim();
    if (path != null && path.isNotEmpty) {
      try {
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefReceiptLogoPath);
    if (mounted) setState(() => _receiptLogoPath = null);
  }

  Future<void> _saveSettings() async {
    await _setSettings();
    _showDialog('Settings saved successfully!');
  }

  Future<void> _resetSettings() async {
    await _clearReceiptLogo();

    _storeName = "My Store";
    _printerIp = _defaultPrinterIp;
    _selectedHour = '09';
    _selectedMinute = '00';
    _selectedAmPm = 'AM';

    _enableDelete = false;
    _appLetter = 'A';
    _orderNoMaxLength = 4;

    await _setSettings();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
    _showDialog('Settings reset to default successfully!');
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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

    final hasLogo =
        _receiptLogoPath != null && _receiptLogoPath!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Printer Settings'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.store, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Store Information',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _storeName,
                      decoration: const InputDecoration(
                        labelText: 'Store Name',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => _storeName = val,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter a store name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Receipt logo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Optional. Prints centered below the store name on thermal slips (80mm).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: hasLogo
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_receiptLogoPath!),
                                height: 96,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Container(
                              height: 72,
                              width: double.infinity,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'No logo selected',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickReceiptLogo,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Choose logo'),
                        ),
                        if (hasLogo)
                          OutlinedButton.icon(
                            onPressed: _clearReceiptLogo,
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remove'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _printerIp,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Printer IP',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (val) => _printerIp = val,
                      validator: (val) {
                        final t = val?.trim() ?? '';
                        if (t.isEmpty) {
                          return 'Please enter printer IP';
                        }
                        if (!_isValidIpv4(t)) {
                          return 'Please enter a valid IP address';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.settings, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'App Settings',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable Delete Functionality'),
                      subtitle: const Text(
                        'Allow deletion of orders, products, and categories',
                      ),
                      value: _enableDelete,
                      onChanged: (val) {
                        setState(() => _enableDelete = val);
                      },
                    ),
                    const SizedBox(height: 8),
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
                              setState(
                                  () => _orderNoMaxLength = int.parse(val!));
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Shift Time Settings',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
            const SizedBox(height: 10),
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
