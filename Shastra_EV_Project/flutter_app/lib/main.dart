import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ebike_provider.dart';
import 'ui/pages/app_shell_page.dart';

void main() {
  runApp(const ShastraEvApp());
}

class ShastraEvApp extends StatelessWidget {
  const ShastraEvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EbikeProvider(),
      child: MaterialApp(
        title: 'Shastra EV Android',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFF050912),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF00D5FF),
            brightness: Brightness.dark,
          ),
          cardColor: const Color(0xFF0C1223),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(letterSpacing: 0.25),
          ),
          useMaterial3: true,
        ),
        home: const AppShellPage(),
      ),
    );
  }
}
