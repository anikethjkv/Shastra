# Shastra EV Android App (SSH + Telemetry)

This Flutter app connects directly to your e-bike controller over local Wi-Fi using SSH (local IP address), then provides:

- live telemetry (speed, battery, voltage, current, motor temperature)
- rolling live history graph (speed, battery, power)
- control actions (headlight, taillight, indicators, hazard, alert/horn)
- map view with bike location (from telemetry) and phone location

## 1) Prerequisites

- Flutter SDK installed and available in `PATH`
- Android Studio + Android SDK
- e-bike controller reachable from phone on local network (example `192.168.1.50`)
- SSH access enabled on the e-bike computer
- Google Maps Android API key

## 2) Configure Google Maps key

Set key in `android/local.properties`:

```properties
googleMapsApiKey=YOUR_ANDROID_MAPS_KEY
```

The manifest reads this value through `manifestPlaceholders` in `android/app/build.gradle.kts`.

## 3) Install packages

```bash
flutter pub get
```

## 4) Run on Android

```bash
flutter run
```

## 5) In-app connection settings

On the `SSH Connection` card, set:

- `Bike Local IP` (example `192.168.1.50`)
- `SSH Port` (usually `22`)
- `Username`
- `Password`
- `Telemetry Command`
- `Control Template` (must include `{action}` placeholder)

These settings are automatically persisted on-device and restored on next app launch.

Defaults:

- Telemetry command: `ebikectl telemetry --json`
- Control template: `ebikectl {action}`

### Expected telemetry output format

Preferred: JSON from telemetry command, e.g.

```json
{
  "speed_kmph": 42.5,
  "battery_percent": 78,
  "voltage": 52.3,
  "current": 11.2,
  "motor_temp": 43.8,
  "headlight_on": true,
  "taillight_on": true,
  "left_indicator_on": false,
  "right_indicator_on": false,
  "hazard_on": false,
  "latitude": 12.93451,
  "longitude": 77.62611,
  "timestamp": "2026-04-05T07:30:00Z"
}
```

The app also accepts simple `key=value` or `key: value` lines as fallback.

## 6) Live history chart

- The app stores a rolling window of latest telemetry points (up to 60 samples).
- The chart auto-updates while connected and polling telemetry.

### Control actions sent by the app

- `headlight_on`, `headlight_off`
- `taillight_on`, `taillight_off`
- `left_indicator_on`, `left_indicator_off`
- `right_indicator_on`, `right_indicator_off`
- `hazard_on`, `hazard_off`
- `alert`

These are substituted into `Control Template`.

Example:

- Template: `sudo /opt/ebike/control.sh {action}`
- Sent command: `sudo /opt/ebike/control.sh headlight_on`
