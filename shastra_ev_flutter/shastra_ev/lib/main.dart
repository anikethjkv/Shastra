import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'providers/vehicle_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/map_screen.dart';
import 'screens/trip_history_screen.dart';
import 'screens/settings_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── STEP 1: Initialize Firebase ──────────────────────────────────────────
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: 'AIzaSyBbJTBLl6SbGRoSLHhCgsYufVk4rvGfQfw',
        appId: '1:1067464766547:android:61a641a8ca28a6b3c582a6',
        messagingSenderId: '1067464766547',
        projectId: 'shastra-app-90301',
        databaseURL:
            'https://shastra-app-90301-default-rtdb.asia-southeast1.firebasedatabase.app',
        storageBucket: 'shastra-app-90301.firebasestorage.app',
      ),
    );
    debugPrint('✅ Firebase initialized successfully');
  } catch (e) {
    // If Firebase is already initialized (hot restart), ignore the error
    debugPrint('⚠️ Firebase init warning: $e');
  }

  // ── STEP 2: Lock orientation ──────────────────────────────────────────────
  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
  }

  // ── STEP 3: Run App ───────────────────────────────────────────────────────
  runApp(
    ChangeNotifierProvider(
      create: (_) => VehicleProvider()..init(),
      child: const ShastraApp(),
    ),
  );
}

class ShastraApp extends StatelessWidget {
  const ShastraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shastra EV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const AppShell(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    MapScreen(),
    TripHistoryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),
      bottomNavigationBar: _NavBar(
        currentIndex: _index,
        onTap: (i) {
          HapticFeedback.selectionClick();
          setState(() => _index = i);
        },
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _NavBar({required this.currentIndex, required this.onTap});

  static const _items = [
    (
      icon: Icons.dashboard_outlined,
      active: Icons.dashboard,
      label: 'Dashboard'
    ),
    (icon: Icons.map_outlined, active: Icons.map, label: 'Map'),
    (icon: Icons.history_outlined, active: Icons.history, label: 'Trips'),
    (icon: Icons.settings_outlined, active: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg2,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final isActive = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: isActive
                      ? BoxDecoration(
                          color: AppColors.cyan.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.cyan.withOpacity(0.25),
                              width: 1),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.active : item.icon,
                            color: isActive
                                ? AppColors.cyan
                                : AppColors.textMuted,
                            size: 22,
                          ),
                          if (i == 0)
                            Consumer<VehicleProvider>(
                              builder: (_, p, __) => p.data.smokeDetected
                                  ? Positioned(
                                      right: -4,
                                      top: -4,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: isActive
                              ? AppColors.cyan
                              : AppColors.textMuted,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}