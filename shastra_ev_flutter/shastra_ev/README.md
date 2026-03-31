# Shastra EV — Flutter Telemetry App

Real-time electric vehicle dashboard for Android & iOS, backed by **Google Cloud IoT Core + Pub/Sub**.

---

## Architecture

```
EV Bike MCU (ESP32 / STM32)
  │
  └─ MQTT over TLS (port 8883)
        │
        ▼
  Google Cloud IoT Core
  (Device Registry: shastra-ev-registry)
        │
        ├─── Pub/Sub Topic: shastra-telemetry  ◄── Flutter app polls (5Hz)
        │
        └─── Cloud Function (optional)
                └─ Firestore: trip history, alerts log
```

### Data Flow
1. **MCU publishes** JSON telemetry every 100ms to `/devices/{id}/events` via MQTT+TLS
2. **Cloud IoT Core** forwards to Pub/Sub topic automatically
3. **Flutter app** polls `projects/{id}/subscriptions/shastra-telemetry-sub:pull` at 200ms intervals
4. **Commands** (mode change, parking) sent via `modifyCloudToDeviceConfig` → device reads from `/devices/{id}/config`

---

## Project Structure

```
lib/
├── main.dart                    # App entry + navigation shell
├── theme/
│   └── app_theme.dart           # Dark theme, colors, typography
├── models/
│   └── vehicle_data.dart        # VehicleData, TripRecord, enums
├── services/
│   ├── cloud_iot_service.dart   # Google Cloud IoT Core + Pub/Sub
│   ├── demo_service.dart        # Simulated live data (demo/competition)
│   └── firebase_service.dart    # Firebase Realtime DB (alternate backend)
├── providers/
│   └── vehicle_provider.dart    # State management (Provider pattern)
├── screens/
│   ├── dashboard_screen.dart    # Main telemetry dashboard
│   ├── map_screen.dart          # Live GPS tracking map
│   ├── trip_history_screen.dart # Trip log + stats
│   └── settings_screen.dart    # Config, alerts, DB schema
└── widgets/
    ├── speed_gauge.dart         # Syncfusion radial speed gauge
    ├── rpm_gauge.dart           # Syncfusion radial RPM gauge
    ├── battery_widget.dart      # Animated battery indicator
    ├── tilt_indicator.dart      # Gyroscope dot indicator (CustomPainter)
    ├── signal_widget.dart       # Network signal bars
    ├── stat_card.dart           # Generic metric card with progress bar
    └── alert_tile.dart          # Smoke / stand / beam / parking alert
```

---

## Setup Guide

### 1. Flutter & Dependencies

```bash
# Requires Flutter 3.x+
flutter pub get
```

### 2. Google Cloud IoT Core

```bash
# Install gcloud CLI, then:
gcloud iot registries create shastra-ev-registry \
  --region=asia-south1 \
  --event-notification-config=topic=shastra-telemetry

gcloud pubsub topics create shastra-telemetry
gcloud pubsub subscriptions create shastra-telemetry-sub \
  --topic=shastra-telemetry \
  --ack-deadline=10

# Register device
gcloud iot devices create shastra-bike-001 \
  --region=asia-south1 \
  --registry=shastra-ev-registry \
  --public-key path=device_public.pem,type=RSA_X509_PEM
```

### 3. Service Account (for Flutter app auth)

```bash
gcloud iam service-accounts create shastra-app \
  --display-name="Shastra EV App"

gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:shastra-app@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/pubsub.subscriber"

gcloud projects add-iam-policy-binding YOUR_PROJECT \
  --member="serviceAccount:shastra-app@YOUR_PROJECT.iam.gserviceaccount.com" \
  --role="roles/cloudiot.deviceController"

gcloud iam service-accounts keys create assets/service_account.json \
  --iam-account=shastra-app@YOUR_PROJECT.iam.gserviceaccount.com
```

Add to `pubspec.yaml` assets:
```yaml
assets:
  - assets/service_account.json
```

### 4. Google Maps

#### Android
Add to `android/local.properties`:
```
MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
```

Add to `android/app/build.gradle`:
```groovy
defaultConfig {
    manifestPlaceholders = [MAPS_API_KEY: localProperties.getProperty('MAPS_API_KEY', '')]
}
```

#### iOS
Replace `YOUR_IOS_MAPS_API_KEY` in `ios/Runner/Info.plist` and add to `ios/Runner/AppDelegate.swift`:
```swift
import GoogleMaps
GMSServices.provideAPIKey("YOUR_IOS_MAPS_API_KEY")
```

### 5. Switch from Demo → Production

In `lib/providers/vehicle_provider.dart`:
```dart
// Comment out:
final DemoVehicleService _demo = DemoVehicleService();

// Uncomment:
final CloudIoTService _iot = CloudIoTService();

// In init():
await _iot.init();
_sub = _iot.vehicleStream.listen(_onData, ...);

// In setMode():
await _iot.setDriveMode(mode);
```

---

## ESP32 MQTT Payload Format

```json
{
  "speed": 45.2,
  "rpm": 4200,
  "batt_pct": 78.5,
  "hvs_volt": 72.1,
  "volt_u": 48.2,
  "volt_v": 47.6,
  "volt_w": 49.1,
  "motor_temp": 52.0,
  "torque": 34.0,
  "current": 18.5,
  "power_kw": 1.33,
  "tilt_x": 2.1,
  "tilt_y": -0.5,
  "lat": 12.9716,
  "lng": 77.5946,
  "gps_acc": 4.2,
  "mode": "eco",
  "smoke": false,
  "stand": false,
  "beam_high": false,
  "parking": false,
  "signal": 4,
  "latency": 24,
  "bt_conn": true,
  "trip_km": 12.4,
  "session_sec": 1240,
  "timestamp": 1710412800000
}
```

---

## Build APK

```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for competition / deployment)
flutter build apk --release --obfuscate --split-debug-info=build/debug-info

# Split APKs by ABI (smaller size)
flutter build apk --split-per-abi

# iOS
flutter build ios --release
```

APK output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Key Features

| Feature | Implementation |
|---|---|
| Live speed gauge | `syncfusion_flutter_gauges` radial gauge |
| Live RPM gauge | `syncfusion_flutter_gauges` with red-zone |
| Battery indicator | Custom `AnimatedFractionallySizedBox` |
| Tilt sensor | `CustomPainter` gyroscope dot |
| GPS map | `google_maps_flutter` with dark style + polyline trail |
| Phase voltages | Realtime AC ripple simulation / Firebase |
| Drive modes | ECO / SPORT / RACE — changes all physics limits |
| Smoke alert | Animated danger overlay on dashboard + map |
| Trip history | Stored in Firestore / demo list |
| Network status | Signal bars + latency + BT status |
| State management | `provider` package |
| Backend | Google Cloud IoT Core + Pub/Sub (production) |
| Demo mode | `DemoVehicleService` with realistic physics simulation |

---

## Team
**Shastra EV** — Built for competition 🏆
