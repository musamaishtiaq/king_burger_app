import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as im;
import 'package:screenshot/screenshot.dart';

/// One line on the full (tabular) item-list slip image.
class SlipItemRow {
  const SlipItemRow({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
  });

  final String name;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
}

/// One line on the kitchen-style count slip image.
class SlipCountLine {
  const SlipCountLine({required this.quantity, required this.productName});

  final int quantity;
  final String productName;
}

/// Half of 80mm slip width in logical pixels ([pixelRatio] 2 → ~558 dots).
const double _kSlipLogicalWidth = 279;

Duration _slipCaptureDelay(int lineEstimate) {
  if (lineEstimate <= 8) return const Duration(milliseconds: 280);
  if (lineEstimate <= 20) return const Duration(milliseconds: 450);
  return const Duration(milliseconds: 750);
}

Future<void> _ensureSlipFonts() async {
  await GoogleFonts.pendingFonts([
    GoogleFonts.notoNaskhArabic(fontSize: 12, color: Colors.black),
    GoogleFonts.notoNaskhArabic(
      fontSize: 13,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    ),
  ]);
}

TextStyle _slipBodyStyle() => GoogleFonts.notoNaskhArabic(
  fontSize: 12,
  color: Colors.black,
  height: 1.25,
);

TextStyle _slipHeaderStyle() => GoogleFonts.notoNaskhArabic(
  fontSize: 13,
  fontWeight: FontWeight.bold,
  color: Colors.black,
  height: 1.2,
);

/// Rasterizes the item list block (product names can be Urdu) to a bitmap for ESC/POS.
///
/// [themeContext] is optional; when omitted, capture uses the platform fallback view
/// (avoids passing [BuildContext] across async gaps from callers).
Future<im.Image?> rasterItemListSection({
  required List<SlipItemRow> rows,
  BuildContext? themeContext,
  double pixelRatio = 2,
}) async {
  await _ensureSlipFonts();
  if (themeContext != null && !themeContext.mounted) return null;
  final controller = ScreenshotController();
  final Uint8List png = await controller.captureFromLongWidget(
    SizedBox(
      width: _kSlipLogicalWidth,
      child: Material(
        color: Colors.white,
        child: _ItemListRasterWidget(rows: rows),
      ),
    ),
    context: themeContext,
    pixelRatio: pixelRatio,
    constraints: const BoxConstraints(maxWidth: _kSlipLogicalWidth),
    delay: _slipCaptureDelay(2 + rows.length),
  );
  return im.decodeImage(png);
}

/// Rasterizes the kitchen item-count block to a bitmap.
///
/// [themeContext] is optional; see [rasterItemListSection].
Future<im.Image?> rasterItemCountSection({
  required List<SlipCountLine> lines,
  BuildContext? themeContext,
  double pixelRatio = 2,
}) async {
  await _ensureSlipFonts();
  if (themeContext != null && !themeContext.mounted) return null;
  final controller = ScreenshotController();
  final Uint8List png = await controller.captureFromLongWidget(
    SizedBox(
      width: _kSlipLogicalWidth,
      child: Material(
        color: Colors.white,
        child: _ItemCountRasterWidget(lines: lines),
      ),
    ),
    context: themeContext,
    pixelRatio: pixelRatio,
    constraints: const BoxConstraints(maxWidth: _kSlipLogicalWidth),
    delay: _slipCaptureDelay(lines.length + 1),
  );
  return im.decodeImage(png);
}

class _ItemListRasterWidget extends StatelessWidget {
  const _ItemListRasterWidget({required this.rows});

  final List<SlipItemRow> rows;

  @override
  Widget build(BuildContext context) {
    final body = _slipBodyStyle();
    final head = _slipHeaderStyle();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Item', style: head, textAlign: TextAlign.left),
                ),
                SizedBox(
                  width: 30,
                  child: Text('Qty', style: head, textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 44,
                  child: Text('Price', style: head, textAlign: TextAlign.right),
                ),
                SizedBox(
                  width: 44,
                  child: Text('Total', style: head, textAlign: TextAlign.right),
                ),
              ],
            ),
            const Divider(height: 16, thickness: 1, color: Colors.black),
            ...rows.map(
              (r) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        r.name,
                        style: body,
                        textAlign: TextAlign.left,
                      ),
                    ),
                    SizedBox(
                      width: 30,
                      child: Text(
                        '${r.quantity}',
                        style: body,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        r.unitPrice.toStringAsFixed(0),
                        style: body,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      child: Text(
                        r.lineTotal.toStringAsFixed(0),
                        style: body,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemCountRasterWidget extends StatelessWidget {
  const _ItemCountRasterWidget({required this.lines});

  final List<SlipCountLine> lines;

  @override
  Widget build(BuildContext context) {
    final body = _slipBodyStyle();
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: lines
              .map(
                (l) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${l.quantity} × ${l.productName}',
                    style: body,
                    textAlign: TextAlign.left,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
