import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';

class RpmGauge extends StatelessWidget {
  final int rpm;
  final DriveMode mode;

  const RpmGauge({super.key, required this.rpm, required this.mode});

  int get _maxRpm => switch (mode) {
        DriveMode.eco => 4000,
        DriveMode.sport => 6500,
        DriveMode.race => 8000,
      };

  @override
  Widget build(BuildContext context) {
    final pct = rpm / _maxRpm;
    final arcColor = pct < 0.6
        ? AppColors.green
        : pct < 0.8
            ? AppColors.amber
            : AppColors.red;

    return SfRadialGauge(
      enableLoadingAnimation: true,
      animationDuration: 400,
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: _maxRpm.toDouble(),
          startAngle: 150,
          endAngle: 30,
          interval: _maxRpm / 4,
          showLabels: true,
          labelOffset: 12,
          axisLabelStyle: const GaugeTextStyle(
            color: AppColors.textMuted,
            fontSize: 9,
            fontFamily: 'Rajdhani',
          ),
          minorTicksPerInterval: 3,
          minorTickStyle: const MinorTickStyle(
            color: AppColors.border,
            length: 5,
            thickness: 1,
          ),
          majorTickStyle: const MajorTickStyle(
            color: AppColors.textMuted,
            length: 8,
            thickness: 1.5,
          ),
          axisLineStyle: const AxisLineStyle(
            thickness: 10,
            color: AppColors.surface,
          ),
          ranges: [
            GaugeRange(
              startValue: 0,
              endValue: rpm.toDouble().clamp(0, _maxRpm.toDouble()),
              color: arcColor,
              startWidth: 10,
              endWidth: 10,
            ),
            // Red zone
            GaugeRange(
              startValue: _maxRpm * 0.8,
              endValue: _maxRpm.toDouble(),
              color: AppColors.red.withOpacity(0.2),
              startWidth: 10,
              endWidth: 10,
            ),
          ],
          pointers: [
            NeedlePointer(
              value: rpm.toDouble().clamp(0, _maxRpm.toDouble()),
              needleColor: Colors.white,
              needleLength: 0.6,
              needleStartWidth: 1,
              needleEndWidth: 2.5,
              knobStyle: const KnobStyle(
                color: Colors.white,
                sizeUnit: GaugeSizeUnit.logicalPixel,
                knobRadius: 5,
              ),
              enableAnimation: true,
              animationDuration: 200,
            ),
          ],
          annotations: [
            GaugeAnnotation(
              widget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: (rpm / 1000).toStringAsFixed(1),
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: arcColor,
                            height: 1,
                          ),
                        ),
                        const TextSpan(
                          text: 'k',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 16,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'RPM',
                    style: TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              angle: 90,
              positionFactor: 0.5,
            ),
          ],
        ),
      ],
    );
  }
}
