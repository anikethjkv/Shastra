import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/vehicle_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _demoMode = true;
  bool _smokeAlerts = true;
  bool _tiltAlerts = true;
  bool _lowBattAlerts = true;
  int _tiltThreshold = 25;
  int _lowBattThreshold = 20;
  String _vehicleId = 'shastra_bike_001';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg2,
        title: const Text('SETTINGS'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _Section(title: 'Data Source', children: [
            _SwitchTile(
              label: 'Demo Mode',
              subtitle: 'Use simulated data (disable to use Firebase)',
              value: _demoMode,
              onChanged: (v) => setState(() => _demoMode = v),
              color: AppColors.cyan,
            ),
            if (!_demoMode) ...[
              const SizedBox(height: 8),
              _TextTile(
                label: 'Vehicle ID',
                value: _vehicleId,
                onChanged: (v) => setState(() => _vehicleId = v),
              ),
              const SizedBox(height: 8),
              _InfoTile(
                icon: Icons.info_outline,
                message:
                    'Make sure your Firebase Realtime DB is configured in firebase_options.dart and the vehicle MCU is publishing to vehicles/\$vehicleId/live',
                color: AppColors.amber,
              ),
            ],
          ]),
          const SizedBox(height: 12),
          _Section(title: 'Alerts', children: [
            _SwitchTile(
              label: 'Smoke Detection',
              subtitle: 'Alert when smoke sensor triggers',
              value: _smokeAlerts,
              onChanged: (v) => setState(() => _smokeAlerts = v),
              color: AppColors.red,
            ),
            const SizedBox(height: 8),
            _SwitchTile(
              label: 'Tilt Alert',
              subtitle: 'Alert when vehicle tilts dangerously',
              value: _tiltAlerts,
              onChanged: (v) => setState(() => _tiltAlerts = v),
              color: AppColors.amber,
            ),
            if (_tiltAlerts) ...[
              const SizedBox(height: 8),
              _SliderTile(
                label: 'Tilt Threshold',
                value: _tiltThreshold.toDouble(),
                min: 10, max: 45, unit: '°',
                onChanged: (v) => setState(() => _tiltThreshold = v.round()),
                color: AppColors.amber,
              ),
            ],
            const SizedBox(height: 8),
            _SwitchTile(
              label: 'Low Battery Alert',
              subtitle: 'Alert when battery drops below threshold',
              value: _lowBattAlerts,
              onChanged: (v) => setState(() => _lowBattAlerts = v),
              color: AppColors.orange,
            ),
            if (_lowBattAlerts) ...[
              const SizedBox(height: 8),
              _SliderTile(
                label: 'Battery Threshold',
                value: _lowBattThreshold.toDouble(),
                min: 5, max: 40, unit: '%',
                onChanged: (v) => setState(() => _lowBattThreshold = v.round()),
                color: AppColors.orange,
              ),
            ],
          ]),
          const SizedBox(height: 12),
          _Section(title: 'About', children: [
            _InfoRow('App Version', '1.0.0'),
            _InfoRow('Build', 'Flutter 3.x'),
            _InfoRow('Backend', 'Firebase Realtime DB'),
            _InfoRow('Protocol', 'MQTT → Firebase → Flutter'),
            _InfoRow('Team', 'SHASTRA EV'),
          ]),
          const SizedBox(height: 12),
          // Firebase Schema reference card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.bg2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('FIREBASE DB SCHEMA',
                  style: TextStyle(fontSize: 9, letterSpacing: 2,
                    color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text(
                  'vehicles/\n'
                  '  shastra_bike_001/\n'
                  '    live/\n'
                  '      speed, rpm, batt_pct\n'
                  '      hvs_volt, volt_u, volt_v, volt_w\n'
                  '      motor_temp, torque, current\n'
                  '      tilt_x, tilt_y, lat, lng\n'
                  '      mode, smoke, stand, parking\n'
                  '      signal, latency, timestamp\n'
                  '    trips/ { trip_id: {...} }\n'
                  '    commands/ { mode, parking }',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.cyan,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(),
            style: const TextStyle(
              fontSize: 9, letterSpacing: 2.5, color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
            )),
        ),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String label, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color color;
  const _SwitchTile({required this.label, required this.subtitle,
    required this.value, required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              Text(subtitle, style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: color,
          activeTrackColor: color.withOpacity(0.3),
        ),
      ],
    );
  }
}

class _SliderTile extends StatelessWidget {
  final String label, unit;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  final Color color;
  const _SliderTile({required this.label, required this.value,
    required this.min, required this.max, required this.unit,
    required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(
              fontSize: 12, color: AppColors.textSecondary)),
            Text('${value.round()}$unit', style: TextStyle(
              fontFamily: 'Rajdhani', fontSize: 14,
              fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        Slider(
          value: value, min: min, max: max,
          onChanged: onChanged,
          activeColor: color,
          inactiveColor: AppColors.border,
        ),
      ],
    );
  }
}

class _TextTile extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  const _TextTile({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
          fontSize: 12, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        TextField(
          controller: TextEditingController(text: value),
          onChanged: onChanged,
          style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13, color: AppColors.cyan),
          decoration: InputDecoration(
            filled: true, fillColor: AppColors.bg3,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.cyan),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color color;
  const _InfoTile({required this.icon, required this.message, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
            style: TextStyle(fontSize: 11, color: color, height: 1.4))),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(
            fontSize: 12, color: AppColors.textMuted)),
          Text(value, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
