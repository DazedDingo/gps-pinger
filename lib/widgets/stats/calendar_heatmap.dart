import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// 12-week × 7-day calendar heatmap (the GitHub contributions look).
///
/// `counts` is a map from `DateTime(y,m,d)` (local midnight) to a row
/// count for that day. Cells with zero pings render in a low-contrast
/// surface tone; non-zero cells are tinted in 4 quartiles of the
/// primary colour, scaled against the busiest day in the window.
///
/// Tapping a cell calls [onDayTap] with the date — the screen wires
/// that to "open the map filtered to this day".
class CalendarHeatmap extends StatelessWidget {
  final Map<DateTime, int> counts;
  final int weeks;
  final void Function(DateTime day, int count)? onDayTap;

  const CalendarHeatmap({
    super.key,
    required this.counts,
    this.weeks = 12,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final endDay = DateTime(today.year, today.month, today.day);
    // Normalise the column anchor to the most recent Sunday so columns
    // are full weeks; the rightmost column may be partial.
    final startDay =
        endDay.subtract(Duration(days: 7 * weeks - 1 + endDay.weekday % 7));
    var maxCount = 0;
    for (final c in counts.values) {
      if (c > maxCount) maxCount = c;
    }

    final theme = Theme.of(context);
    final empty = theme.colorScheme.surfaceContainerHighest;
    final baseTint = theme.colorScheme.primary;
    Color tintForCount(int n) {
      if (n == 0) return empty;
      if (maxCount <= 0) return empty;
      // 4 quartile bins so the low-traffic days still stand out from
      // empty cells but the busiest day is unambiguously the brightest.
      final q = ((n / maxCount) * 4).clamp(1, 4).round();
      return Color.alphaBlend(
        baseTint.withValues(alpha: 0.18 + 0.18 * (q - 1)),
        empty,
      );
    }

    return LayoutBuilder(builder: (context, c) {
      final cellSize = ((c.maxWidth - (weeks - 1) * 3) / weeks).clamp(8.0, 24.0);
      return SizedBox(
        height: cellSize * 7 + 18 + 6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var w = 0; w < weeks; w += 4)
                  SizedBox(
                    width: (cellSize + 3) * 4,
                    child: Text(
                      _monthLabel(startDay.add(Duration(days: w * 7))),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant.withValues(alpha: .8),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var w = 0; w < weeks; w++)
                    Padding(
                      padding: EdgeInsets.only(right: w == weeks - 1 ? 0 : 3),
                      child: Column(
                        children: [
                          for (var d = 0; d < 7; d++)
                            Padding(
                              padding: EdgeInsets.only(bottom: d == 6 ? 0 : 3),
                              child: _buildCell(
                                context,
                                startDay
                                    .add(Duration(days: w * 7 + d)),
                                endDay,
                                cellSize,
                                tintForCount,
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildCell(
    BuildContext context,
    DateTime day,
    DateTime today,
    double size,
    Color Function(int) tintForCount,
  ) {
    if (day.isAfter(today)) {
      return SizedBox(width: size, height: size);
    }
    final n = counts[day] ?? 0;
    return GestureDetector(
      onTap: onDayTap == null ? null : () => onDayTap!(day, n),
      child: Tooltip(
        message: '${DateFormat.yMd().format(day)} — $n ping${n == 1 ? '' : 's'}',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: tintForCount(n),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  static String _monthLabel(DateTime d) => DateFormat.MMM().format(d);
}
