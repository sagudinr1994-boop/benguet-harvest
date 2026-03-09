import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'env.dart';
import 'price_board.dart';
import 'road_screen.dart';
import 'supply_screen.dart';
import 'me_screen.dart';
import 'map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseKey);
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
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  // 5 screens — Map added as 5th
  static const List<Widget> _screens = [
    PriceBoard(),
    RoadScreen(),
    SupplyScreen(),
    MeScreen(),
    MapScreen(),
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
        BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
      ],
    ),
  );
}
