import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 24-bar radial chart showing pings-per-local-hour.
///
/// `counts` is a length-24 list, `counts[h]` = pings for local hour
/// `h`. Bars sit on a faint ring representing zero; bar length scales
/// against the busiest hour. The 12 / 6 / 18 / 0 cardinal labels are
/// drawn in primary; everything else uses surface tones.
///
/// CustomPainter rather than a chart lib because the four other
/// widgets here use stock Material primitives — adding a chart
/// dependency for one widget is overkill.
class ClockChart extends StatelessWidget {
  final List<int> counts;

  const ClockChart({super.key, required this.counts})
      : assert(counts.length == 24, 'counts must have 24 entries');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: CustomPaint(
          painter: _ClockPainter(
            counts: counts,
            barColor: theme.colorScheme.primary,
            ringColor: theme.colorScheme.surfaceContainerHighest,
            labelColor: theme.colorScheme.onSurfaceVariant,
            cardinalColor: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _ClockPainter extends CustomPainter {
  final List<int> counts;
  final Color barColor;
  final Color ringColor;
  final Color labelColor;
  final Color cardinalColor;

  _ClockPainter({
    required this.counts,
    required this.barColor,
    required this.ringColor,
    required this.labelColor,
    required this.cardinalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outer = math.min(size.width, size.height) / 2 - 18;
    final inner = outer * 0.42;

    final ring = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(center, inner, ring);

    var maxN = 0;
    for (final c in counts) {
      if (c > maxN) maxN = c;
    }

    final bar = Paint()
      ..color = barColor
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = (size.shortestSide / 24) * 0.55;

    for (var h = 0; h < 24; h++) {
      // Hour 0 at the top, then clockwise. Maps to clock-face semantics.
      final angle = (h / 24) * (2 * math.pi) - math.pi / 2;
      final fraction = maxN == 0 ? 0.0 : counts[h] / maxN;
      final length = inner + (outer - inner) * fraction;
      final start = Offset(
        center.dx + math.cos(angle) * inner,
        center.dy + math.sin(angle) * inner,
      );
      final end = Offset(
        center.dx + math.cos(angle) * length,
        center.dy + math.sin(angle) * length,
      );
      if (counts[h] > 0) canvas.drawLine(start, end, bar);
    }

    void label(int hour, String text) {
      final angle = (hour / 24) * (2 * math.pi) - math.pi / 2;
      final p = Offset(
        center.dx + math.cos(angle) * (outer + 10),
        center.dy + math.sin(angle) * (outer + 10),
      );
      final isCardinal = hour % 6 == 0;
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isCardinal ? FontWeight.w600 : FontWeight.w400,
            color: isCardinal ? cardinalColor : labelColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(p.dx - tp.width / 2, p.dy - tp.height / 2),
      );
    }

    label(0, '0');
    label(3, '3');
    label(6, '6');
    label(9, '9');
    label(12, '12');
    label(15, '15');
    label(18, '18');
    label(21, '21');
  }

  @override
  bool shouldRepaint(covariant _ClockPainter old) =>
      old.counts != counts ||
      old.barColor != barColor ||
      old.ringColor != ringColor;
}
