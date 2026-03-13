import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  static final _db = Supabase.instance.client;

  // ── PRICE ENCODER ───────────────────────────────────────

  // Submit a new price to the prices table
  static Future<void> submitPrice({
    required String cropName,
    required double pricePerKg,
    required String market,
  }) async {
    await _db.from('prices').insert({
      'crop_name': cropName,
      'price_per_kilo': pricePerKg,
      'market_name': market,
      'date_for': DateTime.now().toIso8601String().substring(0, 10),
      'status': 'pending',
    });
  }

  // ── ADMIN FARMER LIST ────────────────────────────────────

  // Load all farmers ordered by registration date
  static Future<List<Map<String, dynamic>>> getAllFarmers() async {
    final data = await _db
        .from('farmers')
        .select('''
          id, name, barangay, phone, crops_grown,
          latitude, longitude, role, is_active
        ''')
        .order('name', ascending: true);
    return List<Map<String, dynamic>>.from(data);
  }

  // Get count of supply reports for a farmer
  static Future<int> getSupplyCount(String farmerId) async {
    final data = await _db
        .from('supply_reports')
        .select('id')
        .eq('farmer_id', farmerId);
    return data.length;
  }
}
