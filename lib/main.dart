import 'package:flutter/material.dart';
import 'screens/gps_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GoogleMapsTrackerApp());
}

class GoogleMapsTrackerApp extends StatelessWidget {
  const GoogleMapsTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seedBlue = Color(0xFF1769E0);

    return MaterialApp(
      title: 'Live Location Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedBlue),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1457B8),
          foregroundColor: Colors.white,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      home: const GpsScreen(),
    );
  }
}
