import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import 'price_board.dart';
import 'road_screen.dart';
import 'supply_screen.dart';
import 'me_screen.dart';
import 'tools_screen.dart';
import 'admin_desktop_screen.dart';
import 'app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);
  await AppConfig.instance.init();
  runApp(const BenguetHarvestApp());
}

class BenguetHarvestApp extends StatelessWidget {
  const BenguetHarvestApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Benguet Harvest',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1C3A28)),
      useMaterial3: true,
    ),
    home: Platform.isWindows ? const _DesktopHome() : const AppShell(),
  );
}

/// On Windows: shows AdminDesktopScreen for admins, regular app for others.
class _DesktopHome extends StatelessWidget {
  const _DesktopHome();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: SharedPreferences.getInstance()
          .then((p) => p.getString('farmer_role')),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snap.data == 'admin'
            ? const AdminDesktopScreen()
            : const AppShell();
      },
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // 5 screens — Tools replaces Map (Map is accessible inside Tools)
  static const List<Widget> _screens = [
    PriceBoard(),
    RoadScreen(),
    SupplyScreen(),
    MeScreen(),
    ToolsScreen(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _screens),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      selectedItemColor: const Color(0xFF1C3A28),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      type: BottomNavigationBarType.fixed,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Prices'),
        BottomNavigationBarItem(icon: Icon(Icons.add_road), label: 'Roads'),
        BottomNavigationBarItem(icon: Icon(Icons.agriculture), label: 'Supply'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), label: 'Tools'),
      ],
    ),
  );
}
