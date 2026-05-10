import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dbHelper.dart';
import '../screens/settingsScreen.dart';
import '../screens/printerSettingsScreen.dart';
import '../screens/backupScreen.dart';
import '../utils/app_colors.dart';

class SalesReportScreen extends StatefulWidget {
  @override
  _SalesReportScreenState createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _report = [];
  bool _isLoading = false;
  final DbHelper _dbHelper = DbHelper();

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2023),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart)
          _startDate = picked;
        else
          _endDate = picked;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('timeLimit') ?? '09:00 AM';

      final parts = saved.split(RegExp(r'[: ]')); // ['09','15','PM']
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final ampm = parts[2];

      int shiftHour24 = hour % 12;
      if (ampm == 'PM') shiftHour24 += 12;

      final reportStart = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        shiftHour24,
        minute,
        0,
      );

      final reportEnd = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        shiftHour24,
        minute,
        0,
      ).add(const Duration(days: 1));

      print("-----$reportStart");
      print("-----$reportEnd");
      final data = await _dbHelper.getSalesReport(reportStart, reportEnd);

      // Add a small delay for better UX
      await Future.delayed(const Duration(milliseconds: 500));

      setState(() {
        _report = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalAll = _report.fold<double>(
      0.0,
      (sum, item) => sum + (item['totalPrice'] as num).toDouble(),
    );

    final totalQuantity = _report.fold<int>(
      0,
      (sum, item) => sum + (item['totalQty'] as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'settings':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => SettingsScreen()),
                  );
                  break;
                case 'printer':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => PrinterSettingsScreen()),
                  );
                  break;
                case 'backup':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => BackupScreen()),
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings),
                    SizedBox(width: 8),
                    Text('Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'printer',
                child: Row(
                  children: [
                    Icon(Icons.print),
                    SizedBox(width: 8),
                    Text('Printer Settings'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'backup',
                child: Row(
                  children: [
                    Icon(Icons.backup),
                    SizedBox(width: 8),
                    Text('Backup & Restore'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selection Card
          Card(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.date_range,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Select Date Range',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildDateSelector(
                          label: 'Start Date',
                          date: _startDate,
                          onTap: () => _pickDate(isStart: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDateSelector(
                          label: 'End Date',
                          date: _endDate,
                          onTap: () => _pickDate(isStart: false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _generateReport,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.analytics),
                      label: Text(
                        _isLoading ? 'Generating...' : 'Generate Report',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Summary Cards
          if (_report.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Sales',
                      value: 'Rs. ${totalAll.toStringAsFixed(0)}',
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Items Sold',
                      value: totalQuantity.toString(),
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Report List
          Expanded(
            child: _report.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: _report.length,
                    itemBuilder: (context, index) {
                      final item = _report[index];
                      final percentage = totalAll > 0
                          ? ((item['totalPrice'] as num).toDouble() /
                                totalAll *
                                100)
                          : 0.0;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          title: Text(
                            item['productName'],
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Text(
                                'Quantity: ${item['totalQty']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 3),
                              LinearProgressIndicator(
                                value: percentage / 100,
                                backgroundColor: const Color(0xFFEAEAEA),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${percentage.toStringAsFixed(1)}% of total sales',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'Rs. ${(item['totalPrice'] as num).toStringAsFixed(0)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.primary,
                                    ),
                              ),
                              Text(
                                '${item['totalQty']} sold',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          border: Border.all(color: Colors.transparent),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}/${date.month}/${date.year}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
                Icons.analytics_outlined,
                size: 34,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'No Sales Data',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Select a date range, then generate a report.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
