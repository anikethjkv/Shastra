import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BatteryWidget extends StatelessWidget {
  final double percent; // 0-100
  final double voltage;
  final String health;
  final bool isCharging;

  const BatteryWidget({
    super.key,
    required this.percent,
    required this.voltage,
    required this.health,
    this.isCharging = false,
  });

  Color get _fillColor {
    if (percent > 60) return AppColors.green;
    if (percent > 30) return AppColors.amber;
    return AppColors.red;
  }

  Color get _lowColor {
    if (percent > 60) return const Color(0xFF1A9E3A);
    if (percent > 30) return const Color(0xFFB87A00);
    return const Color(0xFF9E1A1A);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // HVS label + voltage
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HVS',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${voltage.toStringAsFixed(0)}V',
              style: const TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Battery body
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Battery visual
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 44,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedFractionallySizedBox(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        heightFactor: (percent / 100).clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [_lowColor, _fillColor],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Tip
                Positioned(
                  top: -7,
                  child: Container(
                    width: 16,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ),
                ),
                // Flash icon
                if (isCharging)
                  const Icon(Icons.bolt, color: Colors.white70, size: 22),
              ],
            ),
            const SizedBox(width: 12),
            // Labels
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${percent.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  health,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: _fillColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
