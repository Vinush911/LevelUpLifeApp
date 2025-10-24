import 'package:flutter/material.dart';
import 'dart:math';

class StatChartPainter extends CustomPainter {
  final Map<String, int> stats;
  final List<String> statOrder = ['STR', 'DEX', 'END', 'CHA', 'WIS', 'INT'];

  StatChartPainter({required this.stats});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final radius = min(centerX, centerY) * 0.75;
    final angle = (2 * pi) / 6;

    final backgroundPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final statPaint = Paint()
      ..color = Colors.purpleAccent.withOpacity(0.4)
      ..style = PaintingStyle.fill;

    final path = Path();
    for (var i = 0; i < 6; i++) {
      final statValue = stats[statOrder[i]] ?? 10;
      final statRadius = radius * (statValue / 100.0).clamp(0.0, 1.0);

      final x = centerX + statRadius * cos(angle * i - pi / 2);
      final y = centerY + statRadius * sin(angle * i - pi / 2);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, statPaint);

    for (var i = 0; i < 6; i++) {
      final x = centerX + radius * cos(angle * i - pi / 2);
      final y = centerY + radius * sin(angle * i - pi / 2);
      canvas.drawLine(Offset(centerX, centerY), Offset(x, y), backgroundPaint);

      final statName = statOrder[i];
      final statValue = stats[statName] ?? 0;

      final namePainter = TextPainter(
        text: TextSpan(
          text: statName,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      namePainter.layout();

      final valuePainter = TextPainter(
        text: TextSpan(
          text: statValue.toString(),
          style: TextStyle(
              color: Colors.purple.shade100,
              fontSize: 12,
              fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      );
      valuePainter.layout();

      double textX = x - namePainter.width / 2;
      double textY = y;

      if (y < centerY - 10) {
        textY -= (namePainter.height + valuePainter.height + 4);
      } else if (y > centerY + 10) {
        textY += 4;
      } else {
        textY -= (namePainter.height + valuePainter.height) / 2;
        if(x < centerX) textX -= namePainter.width + 8;
        if(x > centerX) textX += 8;
      }

      namePainter.paint(canvas, Offset(textX, textY));
      valuePainter.paint(canvas, Offset(x - valuePainter.width / 2, textY + namePainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
