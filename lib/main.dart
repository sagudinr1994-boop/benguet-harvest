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
import 'inbox_screen.dart';
import 'admin_desktop_screen.dart';
import 'app_config.dart';
import 'auth_service.dart';

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
  int _unreadMessages = 0;
  RealtimeChannel? _msgChannel;
  String? _myId;

  static const List<Widget> _screens = [
    PriceBoard(),
    RoadScreen(),
    SupplyScreen(),
    MeScreen(),
    ToolsScreen(),
    InboxScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _initUnread();
  }

  @override
  void dispose() {
    _msgChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initUnread() async {
    final id = await AuthService.getLocalFarmerId();
    if (id == null || !mounted) return;
    _myId = id;
    await _refreshUnread();
    _msgChannel = Supabase.instance.client
        .channel('shell_unread')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => _refreshUnread(),
        )
        .subscribe();
  }

  Future<void> _refreshUnread() async {
    if (_myId == null || !mounted) return;
    try {
      final convs = await Supabase.instance.client
          .from('conversations')
          .select('id')
          .or('farmer_a_id.eq.$_myId,farmer_b_id.eq.$_myId');
      if ((convs as List).isEmpty) {
        if (mounted) setState(() => _unreadMessages = 0);
        return;
      }
      final ids = convs.map((c) => c['id'] as String).toList();
      final rows = await Supabase.instance.client
          .from('messages')
          .select('id')
          .inFilter('conversation_id', ids)
          .neq('sender_id', _myId!)
          .isFilter('read_at', null);
      if (mounted) setState(() => _unreadMessages = (rows as List).length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _currentIndex, children: _screens),
    bottomNavigationBar: BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) {
        setState(() => _currentIndex = i);
        if (i == 5) _refreshUnread();
      },
      selectedItemColor: const Color(0xFF1C3A28),
      unselectedItemColor: Colors.grey,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
      type: BottomNavigationBarType.fixed,
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Prices'),
        const BottomNavigationBarItem(icon: Icon(Icons.add_road), label: 'Roads'),
        const BottomNavigationBarItem(icon: Icon(Icons.agriculture), label: 'Supply'),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
        const BottomNavigationBarItem(icon: Icon(Icons.handyman_outlined), label: 'Tools'),
        BottomNavigationBarItem(
          label: 'Messages',
          icon: _unreadMessages > 0
              ? Badge(
                  label: Text('$_unreadMessages'),
                  child: const Icon(Icons.chat_bubble_outline),
                )
              : const Icon(Icons.chat_bubble_outline),
        ),
      ],
    ),
  );
}
