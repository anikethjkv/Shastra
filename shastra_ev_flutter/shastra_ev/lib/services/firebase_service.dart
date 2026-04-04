import 'dart:async';
import '../models/vehicle_data.dart';

class VehicleStreamService {
  static final VehicleStreamService _instance = VehicleStreamService._();
  factory VehicleStreamService() => _instance;
  VehicleStreamService._();

  Stream<VehicleData> get vehicleStream =>
      Stream.value(VehicleData(timestamp: DateTime.now()));

  Future<void> setDriveMode(DriveMode mode) async {}

  Future<void> toggleParking(bool engaged) async {}

  Future<List<TripRecord>> getTripHistory({int limit = 10}) async => [];

  Stream<Map<String, bool>> get alertStream => Stream.value({});
}
