import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/vehicle_data.dart';
import '../services/demo_service.dart';

class VehicleProvider extends ChangeNotifier {
  final DemoVehicleService _demo = DemoVehicleService();

  StreamSubscription<VehicleData>? _sub;
  VehicleData _data = VehicleData(timestamp: DateTime.now());
  List<double> _rpmHistory = List.filled(20, 0);
  List<double> _speedHistory = List.filled(20, 0);
  List<TripRecord> _trips = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  String? _error;

  VehicleData get data => _data;
  List<double> get rpmHistory => _rpmHistory;
  List<double> get speedHistory => _speedHistory;
  List<TripRecord> get trips => _trips;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  String? get error => _error;

  // App starts — nothing runs, no fake data
  void init() {}

  // User taps Connect button
  Future<void> connect() async {
    if (_isConnected || _isConnecting) return;
    _isConnecting = true;
    _error = null;
    notifyListeners();

    // Simulates Bluetooth handshake — replace with real BT pairing code
    await Future.delayed(const Duration(seconds: 2));

    _isConnecting = false;
    _isConnected = true;
    _trips = _demo.demoTrips;
    notifyListeners();

    _demo.start();
    _sub = _demo.vehicleStream.listen(
      _onData,
      onError: (e) {
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  // User taps Disconnect
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    _demo.stop();
    _isConnected = false;
    _isConnecting = false;
    _data = VehicleData(timestamp: DateTime.now());
    _rpmHistory = List.filled(20, 0);
    _speedHistory = List.filled(20, 0);
    _trips = [];
    notifyListeners();
  }

  void _onData(VehicleData d) {
    _data = d;
    _rpmHistory = [..._rpmHistory.skip(1), d.rpm.toDouble()];
    _speedHistory = [..._speedHistory.skip(1), d.speedKmh];
    notifyListeners();
  }

  Future<void> setMode(DriveMode mode) async {
    _demo.setMode(mode);
  }

  Future<void> toggleParking() async {
    final newState = !_data.parkingEngaged;
    _demo.setParking(newState);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _demo.stop();
    super.dispose();
  }
}