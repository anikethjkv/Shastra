import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TiltIndicator extends StatelessWidget {
  final double tiltX;
  final double tiltY;

  const TiltIndicator({super.key, required this.tiltX, required this.tiltY});

  @override
  Widget build(BuildContext context) {
    final angle = sqrt(tiltX * tiltX + tiltY * tiltY);
    final px = (tiltX / 30).clamp(-1.0, 1.0) * 20;
    final py = (tiltY / 30).clamp(-1.0, 1.0) * 20;
    final color = angle > 20
        ? AppColors.red
        : angle > 12
            ? AppColors.amber
            : AppColors.cyan;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'TILT',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 64,
          height: 64,
          child: CustomPaint(
            painter: _TiltPainter(px: px, py: py, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${angle.toStringAsFixed(1)}°',
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _TiltPainter extends CustomPainter {
  final double px, py;
  final Color color;

  _TiltPainter({required this.px, required this.py, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Outer ring
    canvas.drawCircle(
      Offset(cx, cy),
      r - 2,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Cross hairs
    final hairPaint = Paint()
      ..color = AppColors.surface2
      ..strokeWidth = 0.8;
    canvas.drawLine(Offset(cx - r + 4, cy), Offset(cx + r - 4, cy), hairPaint);
    canvas.drawLine(Offset(cx, cy - r + 4), Offset(cx, cy + r - 4), hairPaint);

    // Inner circle
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.35,
      Paint()
        ..color = AppColors.surface2
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // Dot
    final dotX = cx + px;
    final dotY = cy + py;
    canvas.drawCircle(
      Offset(dotX, dotY),
      6,
      Paint()
        ..color = color.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(dotX, dotY),
      4,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_TiltPainter old) =>
      old.px != px || old.py != py || old.color != color;
}
