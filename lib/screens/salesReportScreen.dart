import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/dbHelper.dart';

class SalesReportScreen extends StatefulWidget {
  @override
  _SalesReportScreenState createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _report = [];
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
    setState(() => _report = data);
  }

  @override
  Widget build(BuildContext context) {
    final totalAll = _report.fold<double>(
      0.0,
      (sum, item) => sum + (item['totalPrice'] as num).toDouble(),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Sales Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                        'Start: ${_startDate.toLocal().toString().split(' ')[0]}'),
                    ElevatedButton(
                      onPressed: () => _pickDate(isStart: true),
                      child: const Text('Pick Start'),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('End: ${_endDate.toLocal().toString().split(' ')[0]}'),
                    ElevatedButton(
                      onPressed: () => _pickDate(isStart: false),
                      child: const Text('Pick End'),
                    ),
                  ],
                ),
                ElevatedButton(
                  onPressed: _generateReport,
                  child: const Text('Generate'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _report.isEmpty
                ? const Center(child: Text('No data'))
                : ListView.builder(
                    itemCount: _report.length,
                    itemBuilder: (context, index) {
                      final item = _report[index];
                      return ListTile(
                        title: Text(item['productName']),
                        subtitle: Text('Sold: ${item['totalQty']}'),
                        trailing: Text(
                          'Rs. ${(item['totalPrice'] as num).toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.blueGrey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL'),
                Text('Rs. ${totalAll.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          )
        ],
      ),
    );
  }
}
