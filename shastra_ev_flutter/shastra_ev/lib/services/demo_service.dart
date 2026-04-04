import 'dart:async';
import 'dart:math';
import '../models/vehicle_data.dart';

/// Simulates realistic EV telemetry for demo purposes.
/// Replace [vehicleStream] usage with a live telemetry service for production.
class DemoVehicleService {
  static final DemoVehicleService _instance = DemoVehicleService._();
  factory DemoVehicleService() => _instance;
  DemoVehicleService._();

  final Random _rnd = Random();
  final StreamController<VehicleData> _controller =
      StreamController<VehicleData>.broadcast();

  Timer? _timer;
  double _t = 0;

  // Mutable state
  double _speed = 45;
  double _rpm = 4200;
  double _battPct = 78;
  double _motorTemp = 52;
  double _torque = 34;
  double _current = 18;
  double _voltU = 48.2, _voltV = 47.6, _voltW = 49.1;
  double _tiltX = 0, _tiltY = 2.1;
  double _lat = 12.9716, _lng = 77.5946;
  double _tripKm = 0;
  int _sessionSec = 0;
  DriveMode _mode = DriveMode.eco;
  bool _smoke = false;
  bool _parking = false;
  int _signalStrength = 4;

  static const _modeParams = {
    DriveMode.eco:   {'maxSpd': 60.0, 'maxRpm': 4000.0, 'maxTorq': 40.0, 'maxCurr': 25.0, 'maxTemp': 60.0},
    DriveMode.sport: {'maxSpd': 90.0, 'maxRpm': 6500.0, 'maxTorq': 65.0, 'maxCurr': 45.0, 'maxTemp': 80.0},
    DriveMode.race:  {'maxSpd': 120.0,'maxRpm': 8000.0, 'maxTorq': 90.0, 'maxCurr': 70.0, 'maxTemp': 95.0},
  };

  Stream<VehicleData> get vehicleStream => _controller.stream;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void stop() {
    _timer?.cancel();
    _controller.close();
  }

  void setMode(DriveMode mode) => _mode = mode;
  void setParking(bool p) => _parking = p;

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _clamp(double v, double mn, double mx) => v.clamp(mn, mx);
  double _noise(double scale) => (_rnd.nextDouble() * 2 - 1) * scale;

  void _tick() {
    _t += 0.05;
    final p = _modeParams[_mode]!;

    // Speed: sinusoidal riding pattern + noise
    final targetSpd = p['maxSpd']! * (0.3 + 0.5 * sin(_t * 0.3)) + _noise(3);
    _speed = _lerp(_speed, _clamp(targetSpd, 0, p['maxSpd']!), 0.08);

    // RPM: correlated with speed
    final targetRpm = (_speed / p['maxSpd']!) * p['maxRpm']! + _noise(200);
    _rpm = _lerp(_rpm, _clamp(targetRpm, 0, p['maxRpm']!), 0.1);

    // Phase voltages: AC ripple simulation (120° phase offset)
    _voltU = 48.0 + sin(_t * 2.1) * 0.8 + _noise(0.1);
    _voltV = 47.5 + sin(_t * 2.1 + 2.094) * 0.8 + _noise(0.1);
    _voltW = 49.0 + sin(_t * 2.1 + 4.189) * 0.8 + _noise(0.1);

    // Battery drains with load
    final load = _speed / p['maxSpd']!;
    _battPct = (_battPct - 0.003 * (1 + load)).clamp(0, 100);

    // Motor temp follows load
    final targetTemp = 35 + load * (p['maxTemp']! - 35) + _noise(1);
    _motorTemp = _lerp(_motorTemp, targetTemp, 0.02);

    // Torque & current
    _torque = _lerp(_torque, load * p['maxTorq']! + _noise(2), 0.1);
    _current = _lerp(_current, load * p['maxCurr']! + _noise(1), 0.1);

    // Tilt: realistic riding tilt
    _tiltX = sin(_t * 0.7) * 8 + _noise(1);
    _tiltY = cos(_t * 0.5) * 6 + _noise(1);

    // GPS drift (simulate movement)
    _lat += _noise(0.00005);
    _lng += _noise(0.00005);

    // Trip odometer
    _tripKm += _speed * 0.1 / 3600;
    _sessionSec++;

    // Rare smoke alert
    if (_rnd.nextDouble() < 0.0003 && !_smoke) {
      _smoke = true;
      Future.delayed(const Duration(seconds: 4), () => _smoke = false);
    }

    // Signal fluctuation
    if (_rnd.nextDouble() < 0.01) {
      _signalStrength = (_signalStrength + (_rnd.nextBool() ? 1 : -1)).clamp(1, 5);
    }

    final hvs = _voltU + _voltV + _voltW;
    final rangeKm = _battPct * 1.12;
    final powerKw = (_current * hvs) / 1000;

    _controller.add(VehicleData(
      speedKmh: _speed,
      rpm: _rpm.round(),
      tiltX: _tiltX,
      tiltY: _tiltY,
      batteryPercent: _battPct,
      hvsVoltage: hvs,
      batteryTemp: 28 + load * 15,
      batteryHealth: _battPct > 70 ? 'GOOD' : _battPct > 40 ? 'FAIR' : 'LOW',
      voltU: _voltU,
      voltV: _voltV,
      voltW: _voltW,
      motorTemp: _motorTemp,
      torqueNm: _torque,
      currentAmps: _current,
      powerKw: powerKw,
      mode: _mode,
      smokeDetected: _smoke,
      standDeployed: false,
      beamHigh: false,
      parkingEngaged: _parking,
      latitude: _lat,
      longitude: _lng,
      gpsAccuracy: 3 + _noise(2).abs(),
      signalStrength: _signalStrength,
      latencyMs: 18 + _rnd.nextInt(20),
      bluetoothConnected: true,
      tripDistanceKm: _tripKm,
      estimatedRangeKm: rangeKm,
      efficiencyPercent: 90 + _noise(5),
      sessionSeconds: _sessionSec,
      timestamp: DateTime.now(),
    ));
  }

  List<TripRecord> get demoTrips => List.generate(8, (i) {
        final start = DateTime.now().subtract(Duration(days: i, hours: 8));
        final end = start.add(Duration(minutes: 25 + i * 7));
        return TripRecord(
          id: 'trip_$i',
          startTime: start,
          endTime: end,
          distanceKm: 8.5 + i * 2.3,
          energyUsedKwh: 1.2 + i * 0.4,
          avgSpeedKmh: 32 + i * 2.5,
          maxSpeedKmh: 65 + i * 5.0,
          avgEfficiency: 88 + (i % 3) * 3.0,
        );
      });
}
