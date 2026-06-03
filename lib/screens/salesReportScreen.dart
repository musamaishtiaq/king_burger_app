import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../widgets/dbHelper.dart';
import '../utils/app_colors.dart';
import '../utils/app_theme_extensions.dart';
import '../utils/layout_breakpoints.dart';
import '../utils/subscription_gate.dart';

class SalesReportScreen extends StatefulWidget {
  @override
  _SalesReportScreenState createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();
  List<Map<String, dynamic>> _itemReport = [];
  List<Order> _ordersInRange = [];
  bool _isLoading = false;
  bool _reportLoaded = false;
  bool _enableReporting = false;
  /// When false (default): show order list. When true: show aggregated product stats.
  bool _showItemLevelStats = false;
  final DbHelper _dbHelper = DbHelper();

  @override
  void initState() {
    super.initState();
    _refreshFromSettings();
  }

  Future<void> _refreshFromSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final enabled = prefs.getBool('enableReporting') ?? false;
    final range = FreePlanLimits.normalizeReportingRange(
      start: FreePlanLimits.today,
      end: FreePlanLimits.today,
    );
    setState(() {
      _enableReporting = enabled;
      _startDate = range.start;
      _endDate = range.end;
      _reportLoaded = false;
      _itemReport = [];
      _ordersInRange = [];
      _isLoading = false;
      _showItemLevelStats = false;
    });
  }

  void _applyReportingRange({DateTime? start, DateTime? end}) {
    final range = FreePlanLimits.normalizeReportingRange(
      start: start ?? _startDate,
      end: end ?? _endDate,
    );
    _startDate = range.start;
    _endDate = range.end;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = FreePlanLimits.today;
    final earliest = FreePlanLimits.reportingEarliestStart;

    final DateTime firstDate;
    final DateTime lastDate;
    late final DateTime initialDate;

    if (isStart) {
      firstDate = earliest;
      lastDate = today;
      initialDate = FreePlanLimits.clampReportingDate(_startDate);
    } else {
      firstDate = FreePlanLimits.reportingEndFirstDate(_startDate);
      lastDate = today;
      var endInitial = FreePlanLimits.clampReportingDate(_endDate);
      if (endInitial.isBefore(firstDate)) endInitial = firstDate;
      if (endInitial.isAfter(lastDate)) endInitial = lastDate;
      initialDate = endInitial;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _applyReportingRange(start: FreePlanLimits.dateOnly(picked));
        } else {
          _applyReportingRange(end: FreePlanLimits.dateOnly(picked));
        }
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _applyReportingRange();
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

      final itemData = await _dbHelper.getSalesReport(reportStart, reportEnd);
      final orders = await _dbHelper.getOrdersForSalesReport(reportStart, reportEnd);

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      setState(() {
        _itemReport = itemData;
        _ordersInRange = orders;
        _reportLoaded = true;
        _showItemLevelStats = false;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  double get _ordersTotalRevenue =>
      _ordersInRange.fold<double>(0, (s, o) => s + o.totalPrice);

  @override
  Widget build(BuildContext context) {
    final itemTotalAll = _itemReport.fold<double>(
      0.0,
      (sum, item) => sum + (item['totalPrice'] as num).toDouble(),
    );

    final itemTotalQuantity = _itemReport.fold<int>(
      0,
      (sum, item) => sum + (item['totalQty'] as num).toInt(),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Reports'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: contentMaxWidth(context)),
          child: Column(
            children: [
              Card(
                margin: EdgeInsets.fromLTRB(
                  horizontalScreenPadding(context),
                  8,
                  horizontalScreenPadding(context),
                  8,
                ),
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
                      const SizedBox(height: 6),
                      Text(
                        'Free plan: start and end dates within the last 30 days, up to today. End date cannot be before start date.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || !_enableReporting)
                              ? null
                              : _generateReport,
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
              if (_reportLoaded) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalScreenPadding(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Orders'),
                          selected: !_showItemLevelStats,
                          onSelected: (_) {
                            setState(() => _showItemLevelStats = false);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: !_showItemLevelStats
                                ? AppColors.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Item stats'),
                          selected: _showItemLevelStats,
                          onSelected: (_) {
                            setState(() => _showItemLevelStats = true);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.2),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: _showItemLevelStats
                                ? AppColors.primary
                                : context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_reportLoaded && !_showItemLevelStats && _ordersInRange.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalScreenPadding(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Orders',
                          value: '${_ordersInRange.length}',
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total sales',
                          value: 'Rs. ${_ordersTotalRevenue.toStringAsFixed(0)}',
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (_reportLoaded && _showItemLevelStats && _itemReport.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalScreenPadding(context),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Total Sales',
                          value: 'Rs. ${itemTotalAll.toStringAsFixed(0)}',
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard(
                          title: 'Items Sold',
                          value: itemTotalQuantity.toString(),
                          color: context.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: !_reportLoaded
                    ? _buildEmptyState()
                    : _showItemLevelStats
                        ? _buildItemStatsBody(
                            context,
                            itemTotalAll,
                          )
                        : _buildOrdersBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersBody(BuildContext context) {
    if (_ordersInRange.isEmpty) {
      return _buildNoDataState(
        icon: Icons.receipt_long_outlined,
        title: 'No orders in range',
        subtitle: 'Try a different date range or generate again.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        horizontalScreenPadding(context),
        0,
        horizontalScreenPadding(context),
        rootTabBodyBottomScrollPadding(context),
      ),
      itemCount: _ordersInRange.length,
      itemBuilder: (context, index) {
        final order = _ordersInRange[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 10,
            ),
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
              'Order #${order.orderNumber}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  _formatOrderDateTime(order.dateTime),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (order.customerDetails.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    order.customerDetails,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            trailing: Text(
              'Rs. ${order.totalPrice.toStringAsFixed(0)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemStatsBody(
    BuildContext context,
    double itemTotalAll,
  ) {
    if (_itemReport.isEmpty) {
      return _buildNoDataState(
        icon: Icons.inventory_2_outlined,
        title: 'No product sales',
        subtitle: 'No line items matched this range.',
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        horizontalScreenPadding(context),
        0,
        horizontalScreenPadding(context),
        rootTabBodyBottomScrollPadding(context),
      ),
      itemCount: _itemReport.length,
      itemBuilder: (context, index) {
        final item = _itemReport[index];
        final percentage = itemTotalAll > 0
            ? ((item['totalPrice'] as num).toDouble() / itemTotalAll * 100)
            : 0.0;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
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
              item['productName'] as String,
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
                  backgroundColor: context.extras.progressTrack,
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
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
    );
  }

  Widget _buildNoDataState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 56, color: context.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatOrderDateTime(String dateTime) {
    final parsed = Order.parseStoredDateTime(dateTime);
    if (parsed == null) return dateTime;
    return DateFormat('d/M/yyyy HH:mm').format(parsed);
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
          color: context.extras.mutedFill,
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
