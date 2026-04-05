import 'dart:convert';

class TelemetryData {
  const TelemetryData({
    required this.speedKmph,
    required this.batteryPercent,
    required this.voltage,
    required this.current,
    required this.motorTemp,
    required this.headlightOn,
    required this.taillightOn,
    required this.leftIndicatorOn,
    required this.rightIndicatorOn,
    required this.hazardOn,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory TelemetryData.empty() {
    return TelemetryData(
      speedKmph: 0,
      batteryPercent: 0,
      voltage: 0,
      current: 0,
      motorTemp: 0,
      headlightOn: false,
      taillightOn: false,
      leftIndicatorOn: false,
      rightIndicatorOn: false,
      hazardOn: false,
      latitude: null,
      longitude: null,
      timestamp: DateTime.now(),
    );
  }

  factory TelemetryData.fromRawOutput(String output) {
    final trimmed = output.trim();
    if (trimmed.isEmpty) {
      return TelemetryData.empty();
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        return TelemetryData.fromMap(decoded);
      }
      if (decoded is Map) {
        return TelemetryData.fromMap(decoded.cast<String, dynamic>());
      }
    } catch (_) {}

    return TelemetryData.fromMap(_parseKeyValueLines(trimmed));
  }

  factory TelemetryData.fromMap(Map<String, dynamic> map) {
    final now = DateTime.now();
    return TelemetryData(
      speedKmph: _asDouble(map['speed_kmph'] ?? map['speed']),
      batteryPercent: _asDouble(map['battery_percent'] ?? map['battery']),
      voltage: _asDouble(map['voltage']),
      current: _asDouble(map['current']),
      motorTemp: _asDouble(map['motor_temp'] ?? map['temperature']),
      headlightOn: _asBool(map['headlight_on'] ?? map['headlight']),
      taillightOn: _asBool(map['taillight_on'] ?? map['taillight']),
      leftIndicatorOn: _asBool(map['left_indicator_on'] ?? map['left_indicator']),
      rightIndicatorOn: _asBool(map['right_indicator_on'] ?? map['right_indicator']),
      hazardOn: _asBool(map['hazard_on'] ?? map['hazard']),
      latitude: _asNullableDouble(map['latitude'] ?? map['lat']),
      longitude: _asNullableDouble(map['longitude'] ?? map['lon']),
      timestamp: _asDateTime(map['timestamp']) ?? now,
    );
  }

  final double speedKmph;
  final double batteryPercent;
  final double voltage;
  final double current;
  final double motorTemp;
  final bool headlightOn;
  final bool taillightOn;
  final bool leftIndicatorOn;
  final bool rightIndicatorOn;
  final bool hazardOn;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  static Map<String, dynamic> _parseKeyValueLines(String output) {
    final map = <String, dynamic>{};
    for (final line in output.split('\n')) {
      final cleaned = line.trim();
      if (cleaned.isEmpty) {
        continue;
      }
      final separatorIndex = cleaned.contains('=')
          ? cleaned.indexOf('=')
          : cleaned.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }
      final key = cleaned.substring(0, separatorIndex).trim();
      final value = cleaned.substring(separatorIndex + 1).trim();
      map[key] = value;
    }
    return map;
  }

  static double _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' ||
          normalized == '1' ||
          normalized == 'on' ||
          normalized == 'yes';
    }
    return false;
  }

  static DateTime? _asDateTime(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
