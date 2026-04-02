import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
  bool _followVehicle = true;
  late AnimationController _dotAnim;

  @override
  void initState() {
    super.initState();
    _dotAnim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _dotAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, provider, _) {
        final d = provider.data;
        // On web: show rich placeholder. On mobile: GoogleMap loads via platform view.
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: Column(
              children: [
                _TopBar(d: d),
                const SizedBox(height: 8),
                Expanded(
                  child: _MapArea(
                    d: d,
                    dotAnim: _dotAnim,
                    followVehicle: _followVehicle,
                    onCameraMove: () =>
                        setState(() => _followVehicle = false),
                    onRecenter: () => setState(() => _followVehicle = true),
                  ),
                ),
                const SizedBox(height: 8),
                _TelemetryStrip(d: d),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── TOP BAR ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VehicleData d;
  const _TopBar({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on, color: AppColors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('LIVE TRACKING',
                    style: TextStyle(fontSize: 9, letterSpacing: 2,
                        color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                Text(
                  '${d.latitude.abs().toStringAsFixed(5)}° N   '
                  '${d.longitude.abs().toStringAsFixed(5)}° E',
                  style: const TextStyle(fontFamily: 'monospace',
                      fontSize: 11, color: AppColors.cyan),
                ),
              ],
            ),
          ),
          Text('±${d.gpsAccuracy.toStringAsFixed(0)}m',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          if (kIsWeb) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.amber.withOpacity(0.3)),
              ),
              child: const Text('ANDROID ONLY',
                  style: TextStyle(fontSize: 8, letterSpacing: 1.5,
                      color: AppColors.amber, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── MAP AREA ──────────────────────────────────────────────────────────────────
class _MapArea extends StatelessWidget {
  final VehicleData d;
  final AnimationController dotAnim;
  final bool followVehicle;
  final VoidCallback onCameraMove;
  final VoidCallback onRecenter;

  const _MapArea({
    required this.d,
    required this.dotAnim,
    required this.followVehicle,
    required this.onCameraMove,
    required this.onRecenter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fake map grid (web + fallback)
            CustomPaint(painter: _MapGridPainter()),

            // Center: pulsing dot + info
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PulsingDot(anim: dotAnim),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.bg.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text('VEHICLE POSITION',
                            style: TextStyle(fontSize: 9, letterSpacing: 2.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 10),
                        Text('${d.latitude.abs().toStringAsFixed(5)}° N',
                            style: const TextStyle(fontFamily: 'monospace',
                                fontSize: 16, color: AppColors.cyan,
                                letterSpacing: 1)),
                        Text('${d.longitude.abs().toStringAsFixed(5)}° E',
                            style: const TextStyle(fontFamily: 'monospace',
                                fontSize: 16, color: AppColors.cyan,
                                letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CoordChip(Icons.speed,
                                '${d.speedKmh.toStringAsFixed(0)} km/h',
                                AppColors.cyan),
                            const SizedBox(width: 8),
                            _CoordChip(Icons.battery_charging_full,
                                '${d.batteryPercent.toStringAsFixed(0)}%',
                                AppColors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (kIsWeb)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.cyan.withOpacity(0.2)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_android,
                              color: AppColors.cyan, size: 13),
                          SizedBox(width: 8),
                          Text('Install on Android to see live map',
                              style: TextStyle(
                                  fontSize: 11, color: AppColors.cyan)),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Map controls (top-right)
            Positioned(
              top: 12, right: 12,
              child: Column(
                children: [
                  _MapBtn(
                    icon: followVehicle
                        ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: followVehicle
                        ? AppColors.cyan : AppColors.textMuted,
                    onTap: onRecenter,
                  ),
                  const SizedBox(height: 8),
                  _MapBtn(
                    icon: Icons.layers_outlined,
                    color: AppColors.textMuted,
                    onTap: () {},
                  ),
                ],
              ),
            ),

            // Smoke alert overlay
            if (d.smokeDetected)
              Positioned(
                top: 12, left: 12, right: 60,
                child: _AlertBanner(
                  message: '⚠  SMOKE DETECTED',
                  color: AppColors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CoordChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _CoordChip(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(fontSize: 11, color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── MAP GRID PAINTER ──────────────────────────────────────────────────────────
class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFF161B27)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Fake roads
    void road(double x1, double y1, double x2, double y2, double w) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2),
            Paint()..color = const Color(0xFF252A38)..strokeWidth = w..strokeCap = StrokeCap.round);

    road(0, size.height * 0.38, size.width, size.height * 0.38, 10);
    road(0, size.height * 0.65, size.width, size.height * 0.65, 5);
    road(size.width * 0.3, 0, size.width * 0.3, size.height, 10);
    road(size.width * 0.72, 0, size.width * 0.72, size.height, 5);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── PULSING DOT ───────────────────────────────────────────────────────────────
class _PulsingDot extends StatelessWidget {
  final AnimationController anim;
  const _PulsingDot({required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 60 + anim.value * 18,
            height: 60 + anim.value * 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withOpacity(0.05 + anim.value * 0.05),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withOpacity(0.1),
              border: Border.all(
                  color: AppColors.cyan.withOpacity(0.5 + anim.value * 0.5),
                  width: 2),
            ),
          ),
          Container(
            width: 14, height: 14,
            decoration: const BoxDecoration(
                shape: BoxShape.circle, color: AppColors.cyan),
          ),
        ],
      ),
    );
  }
}

// ── SHARED ────────────────────────────────────────────────────────────────────
class _TelemetryStrip extends StatelessWidget {
  final VehicleData d;
  const _TelemetryStrip({required this.d});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('SPEED', '${d.speedKmh.toStringAsFixed(0)}', 'km/h', AppColors.cyan),
          _VDiv(),
          _Stat('BATTERY', '${d.batteryPercent.toStringAsFixed(0)}', '%',
              d.batteryPercent > 50 ? AppColors.green :
              d.batteryPercent > 25 ? AppColors.amber : AppColors.red),
          _VDiv(),
          _Stat('RANGE', '${d.estimatedRangeKm.toStringAsFixed(0)}', 'km', AppColors.green),
          _VDiv(),
          _Stat('TRIP', '${d.tripDistanceKm.toStringAsFixed(1)}', 'km', AppColors.textPrimary),
          _VDiv(),
          _Stat('MODE', d.modeLabel, '', switch (d.mode) {
            DriveMode.eco   => AppColors.eco,
            DriveMode.sport => AppColors.sport,
            DriveMode.race  => AppColors.race,
          }),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _Stat(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 8, letterSpacing: 1.5,
                color: AppColors.textMuted, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(children: [
            TextSpan(text: value,
                style: TextStyle(fontFamily: 'Rajdhani', fontSize: 20,
                    fontWeight: FontWeight.w700, color: color)),
            if (unit.isNotEmpty)
              TextSpan(text: ' $unit',
                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ]),
        ),
      ],
    );
  }
}

class _VDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: AppColors.border);
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.bg2.withOpacity(0.95),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

class _AlertBanner extends StatelessWidget {
  final String message;
  final Color color;
  const _AlertBanner({required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(message,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 1)),
    );
  }
}