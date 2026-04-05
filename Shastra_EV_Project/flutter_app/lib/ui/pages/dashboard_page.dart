import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/ebike_provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _showDetails = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<EbikeProvider>(
      builder: (context, provider, _) {
        final telemetry = provider.telemetry;
        final powerKw = (telemetry.voltage * telemetry.current) / 1000;
        final torqueNm = telemetry.current * 1.6;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF060B15), Color(0xFF03060D)],
              ),
            ),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: () async {
                  await provider.refreshPhoneLocation();
                  await provider.refreshTelemetry();
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
                  children: [
                    _header(provider),
                    const SizedBox(height: 12),
                    _liveToggle(),
                    const SizedBox(height: 14),
                    _sectionLabel('MOTOR & POWER'),
                    const SizedBox(height: 8),
                    _motorCards(
                      motorTemp: telemetry.motorTemp,
                      current: telemetry.current,
                      powerKw: powerKw,
                      torqueNm: torqueNm,
                    ),
                    const SizedBox(height: 14),
                    _sectionLabel('ALERTS'),
                    const SizedBox(height: 8),
                    _alertGrid(provider),
                    const SizedBox(height: 14),
                    _sectionLabel('GPS LOCATION'),
                    const SizedBox(height: 8),
                    _gpsCard(provider),
                    const SizedBox(height: 14),
                    _sectionLabel('NETWORK'),
                    const SizedBox(height: 8),
                    _networkCard(provider),
                    if (_showDetails) ...[
                      const SizedBox(height: 14),
                      _sectionLabel('LIVE HISTORY'),
                      const SizedBox(height: 8),
                      _historyCard(provider),
                      const SizedBox(height: 14),
                      _sectionLabel('QUICK MAP'),
                      const SizedBox(height: 8),
                      _miniMap(provider),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(EbikeProvider provider) {
    final online = provider.isConnected;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _panelBox(),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFFD54A), width: 2),
            ),
            child: const Icon(Icons.bolt, color: Color(0xFF00D5FF), size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SHASTRA',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'EV TELEMETRY',
                  style: TextStyle(color: Color(0xFF8092B7), letterSpacing: 1.8),
                ),
              ],
            ),
          ),
          _statusPill('BT', const Color(0xFF9CFB3A), online),
          const SizedBox(width: 6),
          _statusPill('LIVE', const Color(0xFF00D5FF), online),
          const SizedBox(width: 6),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0x33FF4B5C),
            child: Icon(
              online ? Icons.notifications_active : Icons.notifications_off,
              color: const Color(0xFFFF4B5C),
              size: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String label, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active ? color.withValues(alpha: 0.18) : const Color(0x1FFFFFFF),
        border: Border.all(color: active ? color : const Color(0xFF2C3859)),
      ),
      child: Text(
        label,
        style: TextStyle(color: active ? color : const Color(0xFF90A0C6)),
      ),
    );
  }

  Widget _liveToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: _panelBox(),
      child: Row(
        children: [
          Expanded(
            child: _toggleButton(
              label: 'LIVE',
              selected: !_showDetails,
              onTap: () => setState(() => _showDetails = false),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _toggleButton(
              label: 'DETAILS',
              selected: _showDetails,
              onTap: () => setState(() => _showDetails = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? const Color(0x2200D5FF) : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF00D5FF)
                  : const Color(0xFF22304F),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color:
                  selected ? const Color(0xFF00D5FF) : const Color(0xFF8A9BC1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: const Color(0xFF00D5FF),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF97A8CC),
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _motorCards({
    required double motorTemp,
    required double current,
    required double powerKw,
    required double torqueNm,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _metricPanel(
                'MOTOR TEMP',
                '${motorTemp.toStringAsFixed(0)}°C',
                const Color(0xFFFF7B3D),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricPanel(
                'CURRENT',
                '${current.toStringAsFixed(0)} A',
                const Color(0xFF9CFB3A),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _metricPanel(
                'POWER',
                '${powerKw.toStringAsFixed(1)} kW',
                const Color(0xFFCC6BFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _panelBox(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('TORQUE', style: TextStyle(color: Color(0xFF90A0C6))),
              const SizedBox(height: 6),
              Text(
                '${torqueNm.toStringAsFixed(0)} Nm',
                style: const TextStyle(
                  color: Color(0xFFFF7B3D),
                  fontSize: 38,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: (torqueNm / 100).clamp(0.0, 1.0),
                  backgroundColor: const Color(0xFF172640),
                  color: const Color(0xFFFF7B3D),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricPanel(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF90A0C6))),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 34,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 4,
            width: 46,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertGrid(EbikeProvider provider) {
    final telemetry = provider.telemetry;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _alertCard(
                icon: Icons.air,
                title: 'SMOKE',
                state: telemetry.hazardOn ? 'WARN' : 'CLEAR',
                onTap: provider.isConnected
                    ? () => provider.triggerAction(
                          telemetry.hazardOn ? 'hazard_off' : 'hazard_on',
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _alertCard(
                icon: Icons.pedal_bike,
                title: 'STAND',
                state: telemetry.speedKmph < 1 ? 'UP' : 'RUN',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _alertCard(
                icon: Icons.lightbulb,
                title: 'BEAM',
                state: telemetry.headlightOn ? 'HIGH' : 'LOW',
                onTap: provider.isConnected
                    ? () => provider.triggerAction(
                          telemetry.headlightOn ? 'headlight_off' : 'headlight_on',
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _alertCard(
                icon: Icons.local_parking,
                title: 'PARKING',
                state: telemetry.taillightOn ? 'ON' : 'OFF',
                onTap: provider.isConnected
                    ? () => provider.triggerAction(
                          telemetry.taillightOn ? 'taillight_off' : 'taillight_on',
                        )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _alertCard({
    required IconData icon,
    required String title,
    required String state,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: _panelBox(),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0x332A4A13),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF9CFB3A),
                  size: 0,
                ),
              ),
              const SizedBox(height: 8),
              Icon(icon, color: const Color(0xFF9CFB3A)),
              const SizedBox(height: 6),
              Text(title, style: const TextStyle(color: Color(0xFF95A6CB))),
              const SizedBox(height: 3),
              Text(
                state,
                style: const TextStyle(
                  color: Color(0xFF9CFB3A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gpsCard(EbikeProvider provider) {
    final bike = provider.bikeLatLng;
    final speed = provider.telemetry.speedKmph;
    final battery = provider.telemetry.batteryPercent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF7B3D)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  bike == null
                      ? 'Bike location unavailable'
                      : '${bike.latitude.toStringAsFixed(4)}° N   ${bike.longitude.toStringAsFixed(4)}° E',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              Text(
                '${speed.toStringAsFixed(0)} km/h',
                style: const TextStyle(
                  color: Color(0xFF9CFB3A),
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF1B2A49)),
          const SizedBox(height: 8),
          Row(
            children: [
              _smallStat('Trip', '${(speed / 12).toStringAsFixed(1)} km'),
              _smallStat('Range', '${(battery * 0.9).toStringAsFixed(0)} km'),
              _smallStat('Efficiency', '${(battery * 1.1).clamp(0, 99).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _smallStat(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF8193B8))),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF9CFB3A),
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _networkCard(EbikeProvider provider) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _panelBox(),
      child: Column(
        children: [
          Row(
            children: [
              _chip('SSH', provider.isConnected ? 'ONLINE' : 'OFFLINE'),
              const SizedBox(width: 8),
              _chip(
                'LOCATION',
                provider.phonePosition == null ? 'NO FIX' : 'LOCKED',
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  await provider.refreshTelemetry();
                  await provider.refreshPhoneLocation();
                },
                icon: const Icon(Icons.sync),
                label: const Text('Sync'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: provider.isConnected
                      ? () => provider.triggerAction('alert')
                      : null,
                  child: const Text('ALERT / HORN'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: provider.isConnected
                      ? () => provider.triggerAction(
                            provider.telemetry.hazardOn
                                ? 'hazard_off'
                                : 'hazard_on',
                          )
                      : null,
                  child: Text(
                    provider.telemetry.hazardOn ? 'HAZARD OFF' : 'HAZARD ON',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String title, String value) {
    final active = value == 'ONLINE' || value == 'LOCKED';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: active
            ? const Color(0x1A9CFB3A)
            : const Color(0x1AFF7B3D),
        border: Border.all(
          color: active ? const Color(0xFF9CFB3A) : const Color(0xFFFF7B3D),
        ),
      ),
      child: Text('$title: $value'),
    );
  }

  Widget _historyCard(EbikeProvider provider) {
    final history = provider.telemetryHistory;
    if (history.length < 2) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _panelBox(),
        child: const Text('History chart appears after at least 2 telemetry samples.'),
      );
    }

    final speedSpots = <FlSpot>[];
    final batterySpots = <FlSpot>[];
    final powerSpots = <FlSpot>[];

    for (var i = 0; i < history.length; i++) {
      final item = history[i];
      speedSpots.add(FlSpot(i.toDouble(), item.speedKmph));
      batterySpots.add(FlSpot(i.toDouble(), item.batteryPercent));
      powerSpots.add(FlSpot(i.toDouble(), (item.voltage * item.current) / 1000));
    }

    final maxY = math.max(
      10,
      math.max(
        speedSpots.map((e) => e.y).fold(0.0, math.max),
        math.max(
          batterySpots.map((e) => e.y).fold(0.0, math.max),
          powerSpots.map((e) => e.y).fold(0.0, math.max),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelBox(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Wrap(
            spacing: 12,
            children: [
              _HistoryLegend(color: Colors.orange, label: 'Speed (km/h)'),
              _HistoryLegend(color: Colors.lightGreen, label: 'Battery (%)'),
              _HistoryLegend(color: Colors.purpleAccent, label: 'Power (kW)'),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 190,
            child: LineChart(
              LineChartData(
                minX: 0,
                maxX: (history.length - 1).toDouble(),
                minY: 0,
                maxY: maxY + 5,
                titlesData: const FlTitlesData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY + 5) / 4,
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  _chartLine(speedSpots, Colors.orange),
                  _chartLine(batterySpots, Colors.lightGreen),
                  _chartLine(powerSpots, Colors.purpleAccent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  LineChartBarData _chartLine(List<FlSpot> spots, Color color) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      barWidth: 2.5,
      color: color,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }

  Widget _miniMap(EbikeProvider provider) {
    final bikeLocation = provider.bikeLatLng;
    final phoneLocation = provider.phoneLatLng;
    final initialTarget =
        bikeLocation ?? phoneLocation ?? const LatLng(12.9716, 77.5946);

    final markers = <Marker>{
      if (bikeLocation != null)
        Marker(
          markerId: const MarkerId('bike'),
          position: bikeLocation,
          infoWindow: const InfoWindow(title: 'E-bike'),
        ),
      if (phoneLocation != null)
        Marker(
          markerId: const MarkerId('phone'),
          position: phoneLocation,
          infoWindow: const InfoWindow(title: 'Phone'),
        ),
    };

    return Container(
      height: 240,
      decoration: _panelBox(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(target: initialTarget, zoom: 15),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          markers: markers,
        ),
      ),
    );
  }

  BoxDecoration _panelBox() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF10182D), Color(0xFF0A1121)],
      ),
      border: Border.all(color: const Color(0xFF1A284A)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x33000000),
          blurRadius: 12,
          offset: Offset(0, 6),
        ),
      ],
    );
  }
}

class _HistoryLegend extends StatelessWidget {
  const _HistoryLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
