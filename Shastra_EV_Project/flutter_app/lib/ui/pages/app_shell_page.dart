import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/ebike_provider.dart';
import 'dashboard_page.dart';
import 'settings_page.dart';

class AppShellPage extends StatefulWidget {
  const AppShellPage({super.key});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardPage(),
      const _MapPage(),
      const _TripsPage(),
      const SettingsPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF0A1020),
        indicatorColor: const Color(0x2600D5FF),
        selectedIndex: _selectedIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.timeline_outlined),
            selectedIcon: Icon(Icons.timeline_rounded),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _MapPage extends StatelessWidget {
  const _MapPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<EbikeProvider>(
      builder: (context, provider, _) {
        final bikeLocation = provider.bikeLatLng;
        final phoneLocation = provider.phoneLatLng;
        final initialTarget =
            bikeLocation ?? phoneLocation ?? const LatLng(12.9716, 77.5946);

        final markers = <Marker>{
          if (bikeLocation != null)
            Marker(
              markerId: const MarkerId('bike-map'),
              position: bikeLocation,
              infoWindow: const InfoWindow(title: 'E-bike'),
            ),
          if (phoneLocation != null)
            Marker(
              markerId: const MarkerId('phone-map'),
              position: phoneLocation,
              infoWindow: const InfoWindow(title: 'Phone'),
            ),
        };

        return Scaffold(
          appBar: AppBar(title: const Text('Live Map')),
          body: Column(
            children: [
              Expanded(
                child: GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: initialTarget, zoom: 15),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  markers: markers,
                ),
              ),
              Container(
                width: double.infinity,
                color: const Color(0xFF0A1020),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(child: Text(provider.statusMessage)),
                    TextButton(
                      onPressed: () async {
                        await provider.refreshPhoneLocation();
                        await provider.refreshTelemetry();
                      },
                      child: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripsPage extends StatelessWidget {
  const _TripsPage();

  @override
  Widget build(BuildContext context) {
    return Consumer<EbikeProvider>(
      builder: (context, provider, _) {
        final history = provider.telemetryHistory;
        final avgSpeed = history.isEmpty
            ? 0.0
            : history.map((e) => e.speedKmph).reduce((a, b) => a + b) /
                history.length;
        final maxSpeed = history.isEmpty
            ? 0.0
            : history.map((e) => e.speedKmph).reduce((a, b) => a > b ? a : b);

        return Scaffold(
          appBar: AppBar(title: const Text('Trips')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TripStatCard(label: 'Samples', value: '${history.length}'),
              const SizedBox(height: 10),
              _TripStatCard(
                label: 'Average Speed',
                value: '${avgSpeed.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(height: 10),
              _TripStatCard(
                label: 'Max Speed',
                value: '${maxSpeed.toStringAsFixed(1)} km/h',
              ),
              const SizedBox(height: 10),
              _TripStatCard(
                label: 'Battery',
                value: '${provider.telemetry.batteryPercent.toStringAsFixed(0)} %',
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TripStatCard extends StatelessWidget {
  const _TripStatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0C1223),
        border: Border.all(color: const Color(0xFF1A284A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF90A0C6))),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF9CFB3A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
