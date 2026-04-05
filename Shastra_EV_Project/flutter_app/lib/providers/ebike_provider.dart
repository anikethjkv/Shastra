import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/telemetry.dart';
import '../services/ssh_service.dart';

enum SshConnectionStatus { disconnected, connecting, connected, error }

class EbikeProvider extends ChangeNotifier {
  EbikeProvider() {
    unawaited(_loadSettings());
  }

  static const int _maxHistoryPoints = 60;
  static const String _hostKey = 'ssh_host';
  static const String _portKey = 'ssh_port';
  static const String _usernameKey = 'ssh_username';
  static const String _passwordKey = 'ssh_password';
  static const String _telemetryCommandKey = 'telemetry_command';
  static const String _controlTemplateKey = 'control_template';

  final SshService _sshService = SshService();

  TelemetryData _telemetry = TelemetryData.empty();
  final List<TelemetryData> _telemetryHistory = [];
  Position? _phonePosition;
  Timer? _pollingTimer;

  SshConnectionStatus _connectionStatus = SshConnectionStatus.disconnected;
  String _statusMessage = 'Disconnected';
  bool _runningAction = false;
  bool _settingsLoaded = false;

  String host = '192.168.1.50';
  int port = 22;
  String username = 'pi';
  String password = '';

  String telemetryCommand = 'ebikectl telemetry --json';
  String controlTemplate = 'ebikectl {action}';

  TelemetryData get telemetry => _telemetry;
  List<TelemetryData> get telemetryHistory =>
      List.unmodifiable(_telemetryHistory);
  Position? get phonePosition => _phonePosition;
  SshConnectionStatus get connectionStatus => _connectionStatus;
  String get statusMessage => _statusMessage;
  bool get isConnected => _connectionStatus == SshConnectionStatus.connected;
  bool get isConnecting => _connectionStatus == SshConnectionStatus.connecting;
  bool get runningAction => _runningAction;
  bool get settingsLoaded => _settingsLoaded;

  LatLng? get bikeLatLng {
    if (_telemetry.latitude == null || _telemetry.longitude == null) {
      return null;
    }
    return LatLng(_telemetry.latitude!, _telemetry.longitude!);
  }

  LatLng? get phoneLatLng {
    final phone = _phonePosition;
    if (phone == null) {
      return null;
    }
    return LatLng(phone.latitude, phone.longitude);
  }

  void updateConnectionSettings({
    required String host,
    required int port,
    required String username,
    required String password,
    required String telemetryCommand,
    required String controlTemplate,
  }) {
    this.host = host;
    this.port = port;
    this.username = username;
    this.password = password;
    this.telemetryCommand = telemetryCommand;
    this.controlTemplate = controlTemplate;
    unawaited(_saveSettings());
    notifyListeners();
  }

  Future<void> connect() async {
    _connectionStatus = SshConnectionStatus.connecting;
    _statusMessage = 'Connecting to $host:$port...';
    notifyListeners();

    try {
      await _sshService.connect(
        host: host,
        port: port,
        username: username,
        password: password,
      );
      _connectionStatus = SshConnectionStatus.connected;
      _statusMessage = 'Connected';
      notifyListeners();

      await refreshTelemetry();
      await refreshPhoneLocation();
      _startPolling();
    } catch (error) {
      _connectionStatus = SshConnectionStatus.error;
      _statusMessage = 'Connection failed: $error';
      notifyListeners();
      await disconnect(silent: true);
    }
  }

  Future<void> disconnect({bool silent = false}) async {
    _pollingTimer?.cancel();
    _pollingTimer = null;

    await _sshService.disconnect();

    _connectionStatus = SshConnectionStatus.disconnected;
    _statusMessage = silent ? _statusMessage : 'Disconnected';
    notifyListeners();
  }

  Future<void> refreshTelemetry() async {
    if (!isConnected) {
      return;
    }

    try {
      final raw = await _sshService.runCommand(telemetryCommand);
      _telemetry = TelemetryData.fromRawOutput(raw);
      _telemetryHistory.add(_telemetry);
      if (_telemetryHistory.length > _maxHistoryPoints) {
        _telemetryHistory.removeAt(0);
      }
      _statusMessage = 'Telemetry updated';
      notifyListeners();
    } catch (error) {
      _statusMessage = 'Telemetry error: $error';
      notifyListeners();
    }
  }

  Future<void> refreshPhoneLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      _statusMessage = 'Enable location services on phone';
      notifyListeners();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _statusMessage = 'Location permission denied';
      notifyListeners();
      return;
    }

    _phonePosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    notifyListeners();
  }

  Future<void> triggerAction(String action) async {
    if (!isConnected || _runningAction) {
      return;
    }

    _runningAction = true;
    notifyListeners();

    try {
      final command = controlTemplate.replaceAll('{action}', action);
      await _sshService.runCommand(command);
      _statusMessage = 'Action sent: $action';
      await refreshTelemetry();
    } catch (error) {
      _statusMessage = 'Action failed: $error';
      notifyListeners();
    } finally {
      _runningAction = false;
      notifyListeners();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      unawaited(refreshTelemetry());
    });
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    host = prefs.getString(_hostKey) ?? host;
    port = prefs.getInt(_portKey) ?? port;
    username = prefs.getString(_usernameKey) ?? username;
    password = prefs.getString(_passwordKey) ?? password;
    telemetryCommand =
        prefs.getString(_telemetryCommandKey) ?? telemetryCommand;
    controlTemplate = prefs.getString(_controlTemplateKey) ?? controlTemplate;

    _settingsLoaded = true;
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_hostKey, host);
    await prefs.setInt(_portKey, port);
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_passwordKey, password);
    await prefs.setString(_telemetryCommandKey, telemetryCommand);
    await prefs.setString(_controlTemplateKey, controlTemplate);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    unawaited(_sshService.disconnect());
    super.dispose();
  }
}
