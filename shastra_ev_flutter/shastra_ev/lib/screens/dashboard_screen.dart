import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../models/vehicle_data.dart';
import '../theme/app_theme.dart';
import '../widgets/speed_gauge.dart';
import '../widgets/rpm_gauge.dart';
import '../widgets/battery_widget.dart';
import '../widgets/tilt_indicator.dart';
import '../widgets/signal_widget.dart';
import '../widgets/stat_card.dart';
import '../widgets/alert_tile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VehicleProvider>(
      builder: (context, provider, _) {
        final d = provider.data;
        return Scaffold(
          backgroundColor: AppColors.bg,
          body: SafeArea(
            child: !provider.isConnected
                ? _DisconnectedView(
                    onConnect: provider.connect,
                    isConnecting: provider.isConnecting,
                  )
                : Column(
                    children: [
                      // ── HEADER ──────────────────────────────────────────
                      _Header(data: d, onDisconnect: provider.disconnect),
                      const SizedBox(height: 8),

                      // ── TAB BAR ─────────────────────────────────────────
                      _TabBar(controller: _tabController),
                      const SizedBox(height: 8),

                      // ── TAB CONTENT ─────────────────────────────────────
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // TAB 1 — MAIN DASHBOARD
                            _MainTab(data: d, provider: provider),
                            // TAB 2 — DETAILS
                            _DetailsTab(data: d, provider: provider),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

// ── TAB BAR ───────────────────────────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: AppColors.cyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.cyan, width: 1),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: AppColors.cyan,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        tabs: const [
          Tab(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.speed, size: 14),
                SizedBox(width: 6),
                Text('LIVE'),
              ],
            ),
          ),
          Tab(
            height: 32,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 14),
                SizedBox(width: 6),
                Text('DETAILS'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — MAIN DASHBOARD (clean, no overflow)
// ═══════════════════════════════════════════════════════════════════════════════
class _MainTab extends StatelessWidget {
  final VehicleData data;
  final VehicleProvider provider;
  const _MainTab({required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Mode selector
          _ModeSelector(current: data.mode),
          const SizedBox(height: 10),

          // Voltage row
          _VoltageRow(u: data.voltU, v: data.voltV, w: data.voltW),
          const SizedBox(height: 10),

          // RPM + Speed — FULL WIDTH side by side
          _GaugeRow(data: data),
          const SizedBox(height: 10),

          // Battery + Tilt side by side
          _BatteryTiltRow(data: data),
          const SizedBox(height: 10),

          // Session bar
          _SessionBar(data: data),
        ],
      ),
    );
  }
}

// ── GAUGE ROW (RPM left, Speed right) ────────────────────────────────────────
class _GaugeRow extends StatelessWidget {
  final VehicleData data;
  const _GaugeRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // RPM gauge
        Expanded(
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text('MOTOR RPM',
                    style: TextStyle(fontSize: 9, letterSpacing: 2,
                        color: AppColors.textMuted)),
                Expanded(
                  child: RpmGauge(rpm: data.rpm, mode: data.mode),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Speed gauge
        Expanded(
          child: Container(
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Text('SPEED',
                    style: TextStyle(fontSize: 9, letterSpacing: 2,
                        color: AppColors.textMuted)),
                Expanded(
                  child: SpeedGauge(speed: data.speedKmh, mode: data.mode),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── BATTERY + TILT ROW ────────────────────────────────────────────────────────
class _BatteryTiltRow extends StatelessWidget {
  final VehicleData data;
  const _BatteryTiltRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Battery
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: BatteryWidget(
              percent: data.batteryPercent,
              voltage: data.hvsVoltage,
              health: data.batteryHealth,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Tilt
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: TiltIndicator(
              tiltX: data.tiltX,
              tiltY: data.tiltY,
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — DETAILS (motor temp, current, power, alerts, GPS, network)
// ═══════════════════════════════════════════════════════════════════════════════
class _DetailsTab extends StatelessWidget {
  final VehicleData data;
  final VehicleProvider provider;
  const _DetailsTab({required this.data, required this.provider});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section label
          _SectionLabel('MOTOR & POWER'),
          const SizedBox(height: 8),

          // Motor temp, current, power — 3 cards in a row
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: 'Motor Temp',
                  value: data.motorTemp.toStringAsFixed(0),
                  unit: '°C',
                  accentColor: data.tempAlert == AlertLevel.danger
                      ? AppColors.red
                      : data.tempAlert == AlertLevel.warning
                          ? AppColors.amber
                          : AppColors.orange,
                  barValue: data.motorTemp / 120,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'Current',
                  value: data.currentAmps.toStringAsFixed(0),
                  unit: 'A',
                  accentColor: AppColors.green,
                  barValue: data.currentAmps / 80,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  label: 'Power',
                  value: data.powerKw.toStringAsFixed(1),
                  unit: 'kW',
                  accentColor: AppColors.purple,
                  barValue: data.powerKw / 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Torque full width
          StatCard(
            label: 'Torque',
            value: data.torqueNm.toStringAsFixed(0),
            unit: 'Nm',
            accentColor: AppColors.orange,
            barValue: data.torqueNm / 100,
          ),
          const SizedBox(height: 16),

          // Alerts section
          _SectionLabel('ALERTS'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AlertTile(
                  label: 'Smoke',
                  statusText: data.smokeDetected ? 'DETECTED!' : 'CLEAR',
                  level: data.smokeDetected ? AlertLevel.danger : AlertLevel.ok,
                  icon: Icons.air,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AlertTile(
                  label: 'Stand',
                  statusText: data.standDeployed ? 'DOWN' : 'UP',
                  level: data.standDeployed ? AlertLevel.warning : AlertLevel.ok,
                  icon: Icons.directions_bike,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: AlertTile(
                  label: 'Beam',
                  statusText: data.beamHigh ? 'HIGH' : 'LOW',
                  level: data.beamHigh ? AlertLevel.warning : AlertLevel.ok,
                  icon: Icons.highlight,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AlertTile(
                  label: 'Parking',
                  statusText: data.parkingEngaged ? 'ON' : 'OFF',
                  level: data.parkingEngaged ? AlertLevel.warning : AlertLevel.ok,
                  icon: Icons.local_parking,
                  onTap: () {
                    if (!kIsWeb) HapticFeedback.mediumImpact();
                    provider.toggleParking();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // GPS section
          _SectionLabel('GPS LOCATION'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: AppColors.orange, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bengaluru, KA, India',
                              style: TextStyle(fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                          Text(
                            '${data.latitude.abs().toStringAsFixed(4)}° N  '
                            '${data.longitude.abs().toStringAsFixed(4)}° E',
                            style: const TextStyle(fontFamily: 'monospace',
                                fontSize: 10, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Text('${data.speedKmh.toStringAsFixed(0)} km/h',
                        style: const TextStyle(fontFamily: 'Rajdhani',
                            fontSize: 18, fontWeight: FontWeight.w700,
                            color: AppColors.green)),
                  ],
                ),
                const SizedBox(height: 10),
                const Divider(color: AppColors.border, height: 1),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _TripStat('Trip',
                        '${data.tripDistanceKm.toStringAsFixed(1)} km'),
                    _TripStat('Range',
                        '${data.estimatedRangeKm.toStringAsFixed(0)} km',
                        color: AppColors.green),
                    _TripStat('Efficiency',
                        '${data.efficiencyPercent.toStringAsFixed(0)}%',
                        color: AppColors.cyan),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Network section
          _SectionLabel('NETWORK'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: SignalWidget(
              strength: data.signalStrength,
              latencyMs: data.latencyMs,
              bluetoothConnected: data.bluetoothConnected,
            ),
          ),
          const SizedBox(height: 10),
          _SessionBar(data: data),
        ],
      ),
    );
  }
}

// ── SECTION LABEL ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(
                color: AppColors.cyan,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(fontSize: 10, letterSpacing: 2.5,
                color: AppColors.textMuted, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── DISCONNECTED VIEW ─────────────────────────────────────────────────────────
class _DisconnectedView extends StatefulWidget {
  final VoidCallback onConnect;
  final bool isConnecting;
  const _DisconnectedView(
      {required this.onConnect, required this.isConnecting});

  @override
  State<_DisconnectedView> createState() => _DisconnectedViewState();
}

class _DisconnectedViewState extends State<_DisconnectedView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 120 + _pulse.value * 16,
                    height: 120 + _pulse.value * 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyan
                            .withOpacity(0.08 + _pulse.value * 0.08),
                      ),
                    ),
                  ),
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.cyan
                            .withOpacity(0.12 + _pulse.value * 0.12),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: Icon(Icons.bluetooth_searching,
                        color: AppColors.cyan
                            .withOpacity(0.4 + _pulse.value * 0.6),
                        size: 38),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('NO VEHICLE CONNECTED',
                style: TextStyle(fontFamily: 'Rajdhani', fontSize: 22,
                    fontWeight: FontWeight.w700, letterSpacing: 3,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            const Text(
              'Turn on your Shastra EV and enable\nBluetooth, then tap Connect below',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted,
                  height: 1.7),
            ),
            const SizedBox(height: 32),
            _StepTile(step: '1', text: 'Turn on the EV bike'),
            const SizedBox(height: 10),
            _StepTile(step: '2', text: 'Enable Bluetooth on your phone'),
            const SizedBox(height: 10),
            _StepTile(step: '3', text: 'Tap Connect below'),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: widget.isConnecting ? null : widget.onConnect,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  color: widget.isConnecting
                      ? AppColors.surface
                      : AppColors.cyan.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: widget.isConnecting
                        ? AppColors.border : AppColors.cyan,
                    width: 1.5,
                  ),
                ),
                child: widget.isConnecting
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.cyan)),
                          SizedBox(width: 14),
                          Text('CONNECTING...',
                              style: TextStyle(fontFamily: 'Rajdhani',
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  letterSpacing: 3, color: AppColors.cyan)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bluetooth, color: AppColors.cyan, size: 20),
                          SizedBox(width: 10),
                          Text('CONNECT TO VEHICLE',
                              style: TextStyle(fontFamily: 'Rajdhani',
                                  fontSize: 16, fontWeight: FontWeight.w700,
                                  letterSpacing: 3, color: AppColors.cyan)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.amber.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.amber.withOpacity(0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.amber, size: 14),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Demo mode: tap Connect to simulate a live vehicle',
                      style: TextStyle(fontSize: 11, color: AppColors.amber,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String step, text;
  const _StepTile({required this.step, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.cyan.withOpacity(0.1),
              border: Border.all(color: AppColors.cyan.withOpacity(0.3)),
            ),
            child: Center(
              child: Text(step,
                  style: const TextStyle(fontSize: 12,
                      fontWeight: FontWeight.w700, color: AppColors.cyan)),
            ),
          ),
          const SizedBox(width: 14),
          Text(text,
              style: const TextStyle(fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── HEADER ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final VehicleData data;
  final VoidCallback onDisconnect;
  const _Header({required this.data, required this.onDisconnect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(colors: [
                AppColors.orange, AppColors.amber, AppColors.green,
                AppColors.cyan, AppColors.orange,
              ]),
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: AppColors.bg2),
              child: const Icon(Icons.bolt, color: AppColors.cyan, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SHASTRA',
                  style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18,
                      fontWeight: FontWeight.w700, letterSpacing: 3,
                      color: AppColors.textPrimary)),
              Text('EV TELEMETRY',
                  style: TextStyle(fontSize: 8, letterSpacing: 2,
                      color: AppColors.textMuted)),
            ],
          ),
          const Spacer(),
          _StatusPill(
              label: 'BT', active: data.bluetoothConnected,
              color: AppColors.green),
          const SizedBox(width: 6),
          const _StatusPill(label: 'LIVE', active: true, color: AppColors.cyan),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDisconnect,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.red.withOpacity(0.3)),
              ),
              child: const Icon(Icons.bluetooth_disabled,
                  color: AppColors.red, size: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatefulWidget {
  final String label;
  final bool active;
  final Color color;
  const _StatusPill(
      {required this.label, required this.active, required this.color});

  @override
  State<_StatusPill> createState() => _StatusPillState();
}

class _StatusPillState extends State<_StatusPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) => Container(
              width: 5, height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(0.3 + 0.7 * _c.value),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(widget.label,
              style: TextStyle(fontSize: 9, letterSpacing: 1,
                  fontWeight: FontWeight.w700, color: widget.color)),
        ],
      ),
    );
  }
}

// ── MODE SELECTOR ─────────────────────────────────────────────────────────────
class _ModeSelector extends StatelessWidget {
  final DriveMode current;
  const _ModeSelector({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DriveMode.values.map((m) {
        final isActive = m == current;
        final color = switch (m) {
          DriveMode.eco   => AppColors.eco,
          DriveMode.sport => AppColors.sport,
          DriveMode.race  => AppColors.race,
        };
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: m != DriveMode.eco ? 4 : 0,
              right: m != DriveMode.race ? 4 : 0,
            ),
            child: GestureDetector(
              onTap: () {
                if (!kIsWeb) HapticFeedback.lightImpact();
                context.read<VehicleProvider>().setMode(m);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.12) : AppColors.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isActive ? color : AppColors.border,
                      width: isActive ? 1.5 : 1),
                  boxShadow: isActive
                      ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8)]
                      : [],
                ),
                child: Text(m.name.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Rajdhani', fontSize: 13,
                        fontWeight: FontWeight.w700, letterSpacing: 2,
                        color: isActive ? color : AppColors.textMuted)),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── VOLTAGE ROW ───────────────────────────────────────────────────────────────
class _VoltageRow extends StatelessWidget {
  final double u, v, w;
  const _VoltageRow({required this.u, required this.v, required this.w});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _VoltCard(phase: 'U', volt: u)),
      const SizedBox(width: 8),
      Expanded(child: _VoltCard(phase: 'V', volt: v)),
      const SizedBox(width: 8),
      Expanded(child: _VoltCard(phase: 'W', volt: w)),
    ]);
  }
}

class _VoltCard extends StatelessWidget {
  final String phase;
  final double volt;
  const _VoltCard({required this.phase, required this.volt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('PHASE $phase',
              style: const TextStyle(fontSize: 8, letterSpacing: 2,
                  color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${volt.toStringAsFixed(1)}V',
              style: const TextStyle(fontFamily: 'Rajdhani', fontSize: 18,
                  fontWeight: FontWeight.w700, color: AppColors.cyan)),
        ],
      ),
    );
  }
}

// ── TRIP STAT ─────────────────────────────────────────────────────────────────
class _TripStat extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _TripStat(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        Text(value,
            style: TextStyle(fontFamily: 'Rajdhani', fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

// ── SESSION BAR ───────────────────────────────────────────────────────────────
class _SessionBar extends StatelessWidget {
  final VehicleData data;
  const _SessionBar({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('GCP IOT CORE',
              style: TextStyle(fontFamily: 'monospace', fontSize: 8,
                  color: AppColors.textMuted, letterSpacing: 1)),
          Text('${data.timestamp.toLocal().toString().substring(11, 19)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 8,
                  color: AppColors.textMuted)),
          Text('SESSION: ${data.sessionTime}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 8,
                  color: AppColors.cyan)),
        ],
      ),
    );
  }
}