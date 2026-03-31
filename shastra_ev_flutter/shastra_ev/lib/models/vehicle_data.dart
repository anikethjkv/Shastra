import 'package:flutter/foundation.dart';

enum DriveMode { eco, sport, race }

enum AlertLevel { ok, warning, danger }

class VehicleData {
  // Speed & Motion
  final double speedKmh;
  final int rpm;
  final double tiltX;
  final double tiltY;

  // Battery
  final double batteryPercent;
  final double hvsVoltage;
  final double batteryTemp;
  final String batteryHealth;

  // Phase Voltages
  final double voltU;
  final double voltV;
  final double voltW;

  // Motor
  final double motorTemp;
  final double torqueNm;
  final double currentAmps;
  final double powerKw;

  // Mode & Alerts
  final DriveMode mode;
  final bool smokeDetected;
  final bool standDeployed;
  final bool beamHigh;
  final bool parkingEngaged;

  // GPS
  final double latitude;
  final double longitude;
  final double gpsAccuracy;

  // Network
  final int signalStrength; // 0-5
  final int latencyMs;
  final bool bluetoothConnected;

  // Trip
  final double tripDistanceKm;
  final double estimatedRangeKm;
  final double efficiencyPercent;
  final int sessionSeconds;

  final DateTime timestamp;

  const VehicleData({
    this.speedKmh = 0,
    this.rpm = 0,
    this.tiltX = 0,
    this.tiltY = 0,
    this.batteryPercent = 100,
    this.hvsVoltage = 72,
    this.batteryTemp = 25,
    this.batteryHealth = 'GOOD',
    this.voltU = 48,
    this.voltV = 48,
    this.voltW = 48,
    this.motorTemp = 35,
    this.torqueNm = 0,
    this.currentAmps = 0,
    this.powerKw = 0,
    this.mode = DriveMode.eco,
    this.smokeDetected = false,
    this.standDeployed = false,
    this.beamHigh = false,
    this.parkingEngaged = false,
    this.latitude = 12.9716,
    this.longitude = 77.5946,
    this.gpsAccuracy = 5,
    this.signalStrength = 4,
    this.latencyMs = 24,
    this.bluetoothConnected = true,
    this.tripDistanceKm = 0,
    this.estimatedRangeKm = 87,
    this.efficiencyPercent = 94,
    this.sessionSeconds = 0,
    required this.timestamp,
  });

  // Parse from Firebase Realtime DB snapshot
  factory VehicleData.fromFirebase(Map<dynamic, dynamic> map) {
    return VehicleData(
      speedKmh: (map['speed'] ?? 0).toDouble(),
      rpm: (map['rpm'] ?? 0).toInt(),
      tiltX: (map['tilt_x'] ?? 0).toDouble(),
      tiltY: (map['tilt_y'] ?? 0).toDouble(),
      batteryPercent: (map['batt_pct'] ?? 100).toDouble(),
      hvsVoltage: (map['hvs_volt'] ?? 72).toDouble(),
      batteryTemp: (map['batt_temp'] ?? 25).toDouble(),
      batteryHealth: map['batt_health'] ?? 'GOOD',
      voltU: (map['volt_u'] ?? 48).toDouble(),
      voltV: (map['volt_v'] ?? 48).toDouble(),
      voltW: (map['volt_w'] ?? 48).toDouble(),
      motorTemp: (map['motor_temp'] ?? 35).toDouble(),
      torqueNm: (map['torque'] ?? 0).toDouble(),
      currentAmps: (map['current'] ?? 0).toDouble(),
      powerKw: (map['power_kw'] ?? 0).toDouble(),
      mode: DriveMode.values.firstWhere(
        (m) => m.name == (map['mode'] ?? 'eco'),
        orElse: () => DriveMode.eco,
      ),
      smokeDetected: map['smoke'] ?? false,
      standDeployed: map['stand'] ?? false,
      beamHigh: map['beam_high'] ?? false,
      parkingEngaged: map['parking'] ?? false,
      latitude: (map['lat'] ?? 12.9716).toDouble(),
      longitude: (map['lng'] ?? 77.5946).toDouble(),
      gpsAccuracy: (map['gps_acc'] ?? 5).toDouble(),
      signalStrength: (map['signal'] ?? 4).toInt(),
      latencyMs: (map['latency'] ?? 24).toInt(),
      bluetoothConnected: map['bt_conn'] ?? true,
      tripDistanceKm: (map['trip_km'] ?? 0).toDouble(),
      estimatedRangeKm: (map['range_km'] ?? 87).toDouble(),
      efficiencyPercent: (map['efficiency'] ?? 94).toDouble(),
      sessionSeconds: (map['session_sec'] ?? 0).toInt(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'speed': speedKmh,
        'rpm': rpm,
        'tilt_x': tiltX,
        'tilt_y': tiltY,
        'batt_pct': batteryPercent,
        'hvs_volt': hvsVoltage,
        'batt_temp': batteryTemp,
        'batt_health': batteryHealth,
        'volt_u': voltU,
        'volt_v': voltV,
        'volt_w': voltW,
        'motor_temp': motorTemp,
        'torque': torqueNm,
        'current': currentAmps,
        'power_kw': powerKw,
        'mode': mode.name,
        'smoke': smokeDetected,
        'stand': standDeployed,
        'beam_high': beamHigh,
        'parking': parkingEngaged,
        'lat': latitude,
        'lng': longitude,
        'gps_acc': gpsAccuracy,
        'signal': signalStrength,
        'latency': latencyMs,
        'bt_conn': bluetoothConnected,
        'trip_km': tripDistanceKm,
        'range_km': estimatedRangeKm,
        'efficiency': efficiencyPercent,
        'session_sec': sessionSeconds,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  AlertLevel get batteryAlert =>
      batteryPercent < 15 ? AlertLevel.danger :
      batteryPercent < 30 ? AlertLevel.warning : AlertLevel.ok;

  AlertLevel get tempAlert =>
      motorTemp > 90 ? AlertLevel.danger :
      motorTemp > 70 ? AlertLevel.warning : AlertLevel.ok;

  double get tiltAngle => (tiltX * tiltX + tiltY * tiltY) > 0
      ? (tiltX * tiltX + tiltY * tiltY) * 0.5
      : 0;

  String get modeLabel => mode.name.toUpperCase();

  String get sessionTime {
    final m = sessionSeconds ~/ 60;
    final s = sessionSeconds % 60;
    return '${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }
}

class TripRecord {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceKm;
  final double energyUsedKwh;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double avgEfficiency;

  const TripRecord({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceKm,
    required this.energyUsedKwh,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgEfficiency,
  });

  Duration get duration => endTime.difference(startTime);

  factory TripRecord.fromFirebase(String id, Map map) => TripRecord(
        id: id,
        startTime: DateTime.fromMillisecondsSinceEpoch(map['start']),
        endTime: DateTime.fromMillisecondsSinceEpoch(map['end']),
        distanceKm: (map['distance'] ?? 0).toDouble(),
        energyUsedKwh: (map['energy'] ?? 0).toDouble(),
        avgSpeedKmh: (map['avg_speed'] ?? 0).toDouble(),
        maxSpeedKmh: (map['max_speed'] ?? 0).toDouble(),
        avgEfficiency: (map['efficiency'] ?? 0).toDouble(),
      );
}
