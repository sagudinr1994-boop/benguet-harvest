import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'encoder_screen.dart' hide kMarkets; // kAllCrops (default fallback)
import 'price_board.dart'; // kMarkets (default fallback)

/// Central config loaded from Supabase `crops` and `markets` tables.
/// Falls back to hardcoded constants if tables don't exist yet.
/// Uses Supabase Realtime — any change on Windows pushes instantly to mobile.
class AppConfig extends ChangeNotifier {
  AppConfig._();
  static final AppConfig instance = AppConfig._();

  List<String> crops = List<String>.from(kAllCrops);
  List<String> markets = List<String>.from(kMarkets);

  RealtimeChannel? _channel;

  Future<void> init() async {
    await _load();
    _subscribeRealtime();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('crops')
            .select('name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
        Supabase.instance.client
            .from('markets')
            .select('name')
            .eq('is_active', true)
            .order('sort_order')
            .order('name'),
      ]);
      final newCrops =
          (results[0] as List).map((r) => r['name'] as String).toList();
      final newMarkets =
          (results[1] as List).map((r) => r['name'] as String).toList();
      if (newCrops.isNotEmpty) crops = newCrops;
      if (newMarkets.isNotEmpty) markets = newMarkets;
      notifyListeners();
    } catch (_) {
      // Tables don't exist yet — keep hardcoded defaults
    }
  }

  void _subscribeRealtime() {
    _channel = Supabase.instance.client
        .channel('app_config_changes')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'crops',
          callback: (_) => _load(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'markets',
          callback: (_) => _load(),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }
}
