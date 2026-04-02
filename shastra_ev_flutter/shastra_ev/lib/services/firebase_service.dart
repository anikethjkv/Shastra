import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import '../models/vehicle_data.dart';

class FirebaseVehicleService {
  static const String _vehicleId = 'shastra_bike_001';
  static final FirebaseVehicleService _instance = FirebaseVehicleService._();
  factory FirebaseVehicleService() => _instance;
  FirebaseVehicleService._();

  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // --- Live telemetry stream (10Hz refresh from Firebase) ---
  Stream<VehicleData> get vehicleStream {
    return _db
        .ref('vehicles/$_vehicleId/live')
        .onValue
        .map((event) {
          final data = event.snapshot.value;
          if (data == null) return _defaultData;
          return VehicleData.fromFirebase(
            Map<dynamic, dynamic>.from(data as Map),
          );
        })
        .handleError((e) => _defaultData);
  }

  // --- Send mode change command to bike ---
  Future<void> setDriveMode(DriveMode mode) async {
    await _db.ref('vehicles/$_vehicleId/commands').set({
      'mode': mode.name,
      'ts': ServerValue.timestamp,
    });
  }

  // --- Toggle parking ---
  Future<void> toggleParking(bool engaged) async {
    await _db.ref('vehicles/$_vehicleId/commands').set({
      'parking': engaged,
      'ts': ServerValue.timestamp,
    });
  }

  // --- Fetch trip history ---
  Future<List<TripRecord>> getTripHistory({int limit = 10}) async {
    final snap = await _db
        .ref('vehicles/$_vehicleId/trips')
        .orderByChild('start')
        .limitToLast(limit)
        .get();

    if (!snap.exists || snap.value == null) return [];

    final map = Map<String, dynamic>.from(snap.value as Map);
    return map.entries
        .map((e) => TripRecord.fromFirebase(
              e.key,
              Map<dynamic, dynamic>.from(e.value),
            ))
        .toList()
        .reversed
        .toList();
  }

  // --- Alert stream: listen for smoke/tilt emergency flags ---
  Stream<Map<String, bool>> get alertStream {
    return _db.ref('vehicles/$_vehicleId/alerts').onValue.map((event) {
      if (event.snapshot.value == null) return {};
      final raw = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return raw.map((k, v) => MapEntry(k.toString(), v as bool));
    });
  }

  VehicleData get _defaultData => VehicleData(timestamp: DateTime.now());
}
