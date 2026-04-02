import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SignalWidget extends StatelessWidget {
  final int strength; // 0-5
  final int latencyMs;
  final bool bluetoothConnected;

  const SignalWidget({
    super.key,
    required this.strength,
    required this.latencyMs,
    required this.bluetoothConnected,
  });

  String get _label => strength >= 4
      ? 'STRONG'
      : strength >= 2
          ? 'FAIR'
          : 'WEAK';

  Color get _color => strength >= 4
      ? AppColors.green
      : strength >= 2
          ? AppColors.amber
          : AppColors.red;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Signal bars
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(5, (i) {
            final active = i < strength;
            final h = 6.0 + i * 5.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 8,
                height: h,
                decoration: BoxDecoration(
                  color: active ? _color : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          '4G LTE',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
        Text(
          _label,
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 1,
          color: AppColors.border,
        ),
        const SizedBox(height: 8),
        // Latency
        const Text(
          'LATENCY',
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            color: AppColors.textMuted,
          ),
        ),
        Text(
          '${latencyMs}ms',
          style: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(height: 6),
        // Bluetooth
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bluetooth,
              size: 14,
              color: bluetoothConnected ? AppColors.cyan : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              bluetoothConnected ? 'PAIRED' : 'OFF',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                color: bluetoothConnected ? AppColors.cyan : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
