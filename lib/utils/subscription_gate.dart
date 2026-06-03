import 'package:flutter/material.dart';

/// Free-plan limits and subscription prompts (app is on free tier until billing ships).
class FreePlanLimits {
  FreePlanLimits._();

  static const int reportingLookbackDays = 30;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime get today => dateOnly(DateTime.now());

  static DateTime get reportingEarliestStart =>
      today.subtract(const Duration(days: reportingLookbackDays));

  static DateTime clampReportingDate(DateTime date) {
    final d = dateOnly(date);
    if (d.isBefore(reportingEarliestStart)) return reportingEarliestStart;
    if (d.isAfter(today)) return today;
    return d;
  }

  /// Keeps start/end inside the free 30-day window; end is never before start.
  static ({DateTime start, DateTime end}) normalizeReportingRange({
    required DateTime start,
    required DateTime end,
  }) {
    var s = clampReportingDate(start);
    var e = clampReportingDate(end);
    if (e.isBefore(s)) e = s;
    return (start: s, end: e);
  }

  /// Earliest selectable end date: not before start, not before 30-day window.
  static DateTime reportingEndFirstDate(DateTime start) {
    final s = clampReportingDate(start);
    return s.isAfter(reportingEarliestStart) ? s : reportingEarliestStart;
  }
}

const String subscriptionComingSoonMessage =
    'This is allowed with a subscription plan, which is coming soon.';

Future<void> showSubscriptionRequiredDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Subscription required'),
        content: const Text(subscriptionComingSoonMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      );
    },
  );
}
