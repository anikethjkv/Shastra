import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';

class SpeedGauge extends StatelessWidget {
  final double speed;
  final DriveMode mode;

  const SpeedGauge({super.key, required this.speed, required this.mode});

  double get _maxSpeed => switch (mode) {
        DriveMode.eco => 60,
        DriveMode.sport => 90,
        DriveMode.race => 120,
      };

  List<Color> get _arcColors => switch (mode) {
        DriveMode.eco => [AppColors.green, AppColors.cyan],
        DriveMode.sport => [AppColors.amber, AppColors.orange],
        DriveMode.race => [AppColors.orange, AppColors.red],
      };

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      enableLoadingAnimation: true,
      animationDuration: 500,
      axes: [
        RadialAxis(
          minimum: 0,
          maximum: _maxSpeed,
          startAngle: 150,
          endAngle: 30,
          showLabels: true,
          showTicks: true,
          labelOffset: 15,
          axisLabelStyle: const GaugeTextStyle(
            color: AppColors.textMuted,
            fontSize: 10,
            fontFamily: 'Rajdhani',
          ),
          minorTicksPerInterval: 4,
          minorTickStyle: const MinorTickStyle(
            color: AppColors.border,
            length: 6,
            thickness: 1,
          ),
          majorTickStyle: const MajorTickStyle(
            color: AppColors.textMuted,
            length: 10,
            thickness: 1.5,
          ),
          axisLineStyle: const AxisLineStyle(
            thickness: 14,
            color: AppColors.surface,
            cornerStyle: CornerStyle.bothFlat,
          ),
          ranges: [
            GaugeRange(
              startValue: 0,
              endValue: speed.clamp(0, _maxSpeed),
              gradient: SweepGradient(colors: _arcColors),
              startWidth: 14,
              endWidth: 14,
              rangeOffset: 0,
            ),
          ],
          pointers: [
            NeedlePointer(
              value: speed.clamp(0, _maxSpeed),
              needleColor: Colors.white,
              needleLength: 0.65,
              needleStartWidth: 1,
              needleEndWidth: 3,
              knobStyle: const KnobStyle(
                color: Colors.white,
                sizeUnit: GaugeSizeUnit.logicalPixel,
                knobRadius: 6,
                borderColor: AppColors.surface2,
                borderWidth: 2,
              ),
              enableAnimation: true,
              animationType: AnimationType.ease,
              animationDuration: 300,
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
                          text: speed.toStringAsFixed(0),
                          style: const TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'km/h',
                    style: TextStyle(
                      fontSize: 12,
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
