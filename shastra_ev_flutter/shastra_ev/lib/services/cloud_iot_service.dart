import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/vehicle_data.dart';

/// Google Cloud IoT Core Service
///
/// Architecture:
///   EV Bike MCU (ESP32)
///     └─ MQTT over TLS (port 8883) ──► Cloud IoT Core (Device Registry)
///                                           └─ Pub/Sub Topic: telemetry/shastra-bike
///                                                 └─ Cloud Function ──► Firestore (history)
///                                                 └─ Flutter App subscribes via REST pull
///
/// For real-time updates, this service polls the Cloud Pub/Sub subscription
/// and also supports direct MQTT from the app via IoT Core bridge.
///
/// Setup steps:
///   1. Enable Cloud IoT Core API + Cloud Pub/Sub API in GCP console
///   2. Create device registry: shastra-ev-registry (region: asia-south1)
///   3. Create Pub/Sub topic: projects/{PROJECT_ID}/topics/shastra-telemetry
///   4. Create Pub/Sub subscription: shastra-telemetry-sub
///   5. Add service account JSON to assets/service_account.json
///   6. Flash ESP32 with MQTT client using device private key
///
/// MQTT topic format (IoT Core standard):
///   /devices/{DEVICE_ID}/events          ← telemetry publish
///   /devices/{DEVICE_ID}/config          ← config push (commands)
///   /devices/{DEVICE_ID}/state           ← device state

class CloudIoTService {
  static final CloudIoTService _instance = CloudIoTService._();
  factory CloudIoTService() => _instance;
  CloudIoTService._();

  // ── CONFIG — Replace with your GCP project values ──────────────────────
  static const String projectId = 'YOUR_GCP_PROJECT_ID';
  static const String region = 'asia-south1';
  static const String registryId = 'shastra-ev-registry';
  static const String deviceId = 'shastra-bike-001';
  static const String subscriptionId = 'shastra-telemetry-sub';
  static const String topicId = 'shastra-telemetry';
  // ───────────────────────────────────────────────────────────────────────

  static const String _pubSubBase = 'https://pubsub.googleapis.com/v1';
  static const String _iotBase = 'https://cloudiot.googleapis.com/v1';
  static const String _subPath =
      'projects/$projectId/subscriptions/$subscriptionId';

  final StreamController<VehicleData> _controller =
      StreamController<VehicleData>.broadcast();

  Timer? _pollTimer;
  String? _accessToken;
  DateTime? _tokenExpiry;

  Stream<VehicleData> get vehicleStream => _controller.stream;

  /// Initialize: obtain OAuth2 token, start polling Pub/Sub at 5Hz
  Future<void> init() async {
    await _refreshToken();
    _pollTimer = Timer.periodic(const Duration(milliseconds: 200), (_) => _poll());
  }

  /// Pull messages from Pub/Sub subscription
  Future<void> _poll() async {
    if (_accessToken == null) return;
    if (_tokenExpiry != null && DateTime.now().isAfter(_tokenExpiry!)) {
      await _refreshToken();
    }

    try {
      final uri = Uri.parse('$_pubSubBase/$_subPath:pull');
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode({'maxMessages': 10}));

      final resp = await req.close();
      final body = await resp.transform(utf8.decoder).join();
      client.close();

      if (resp.statusCode != 200) return;

      final json = jsonDecode(body) as Map<String, dynamic>;
      final messages = (json['receivedMessages'] as List?) ?? [];

      final ackIds = <String>[];
      for (final msg in messages) {
        final ackId = msg['ackId'] as String;
        ackIds.add(ackId);

        final data = msg['message']?['data'] as String?;
        if (data != null) {
          final decoded = utf8.decode(base64.decode(data));
          final payload = jsonDecode(decoded) as Map<String, dynamic>;
          _controller.add(VehicleData.fromMap(payload));
        }
      }

      // Acknowledge messages
      if (ackIds.isNotEmpty) await _acknowledge(ackIds);
    } catch (e) {
      debugPrint('[CloudIoT] Poll error: $e');
    }
  }

  Future<void> _acknowledge(List<String> ackIds) async {
    try {
      final uri = Uri.parse('$_pubSubBase/$_subPath:acknowledge');
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.set('Content-Type', 'application/json');
      req.write(jsonEncode({'ackIds': ackIds}));
      final resp = await req.close();
      await resp.drain();
      client.close();
    } catch (_) {}
  }

  /// Send command to device via Cloud IoT Core config update
  Future<void> sendCommand(Map<String, dynamic> command) async {
    if (_accessToken == null) return;
    try {
      final path =
          'projects/$projectId/locations/$region/registries/$registryId/devices/$deviceId';
      final uri = Uri.parse('$_iotBase/$path:modifyCloudToDeviceConfig');
      final client = HttpClient();
      final req = await client.postUrl(uri);
      req.headers.set('Authorization', 'Bearer $_accessToken');
      req.headers.set('Content-Type', 'application/json');
      final payload = base64.encode(utf8.encode(jsonEncode(command)));
      req.write(jsonEncode({'binaryData': payload}));
      final resp = await req.close();
      await resp.drain();
      client.close();
    } catch (e) {
      debugPrint('[CloudIoT] sendCommand error: $e');
    }
  }

  Future<void> setDriveMode(DriveMode mode) =>
      sendCommand({'mode': mode.name, 'ts': DateTime.now().millisecondsSinceEpoch});

  Future<void> toggleParking(bool engaged) =>
      sendCommand({'parking': engaged, 'ts': DateTime.now().millisecondsSinceEpoch});

  /// In production: use google_auth_oauthlib or a service account JWT.
  /// This is a placeholder — use the `googleapis_auth` package with a
  /// service account JSON for real token exchange.
  Future<void> _refreshToken() async {
    // TODO: Implement service account JWT → OAuth2 token exchange
    // Using: https://pub.dev/packages/googleapis_auth
    //
    // final accountCredentials = ServiceAccountCredentials.fromJson(
    //   json.decode(await rootBundle.loadString('assets/service_account.json')),
    // );
    // final scopes = ['https://www.googleapis.com/auth/pubsub',
    //                 'https://www.googleapis.com/auth/cloudiot'];
    // final authClient = await clientViaServiceAccount(accountCredentials, scopes);
    // _accessToken = authClient.credentials.accessToken.data;
    // _tokenExpiry = authClient.credentials.accessToken.expiry;

    debugPrint('[CloudIoT] Token refresh — implement service account auth');
  }

  void dispose() {
    _pollTimer?.cancel();
    _controller.close();
  }
}
