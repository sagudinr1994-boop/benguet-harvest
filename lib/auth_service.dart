import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/foundation.dart'; // for compute()
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Top-level functions required by compute() ────────────────
// compute() runs these in a background isolate so bcrypt
// never blocks the UI thread and the app doesn't freeze.

String _hashPinIsolate(String pin) {
  final salt = BCrypt.gensalt(logRounds: 10);
  return BCrypt.hashpw(pin, salt);
}

bool _verifyPinIsolate(List<String> args) {
  // args[0] = plain PIN, args[1] = stored hash
  return BCrypt.checkpw(args[0], args[1]);
}

// ── AuthService ───────────────────────────────────────────────
class AuthService {
  static const String _farmerIdKey = 'farmer_id';

  // Hash PIN in background — UI stays responsive
  static Future<String> hashPin(String pin) async {
    return compute(_hashPinIsolate, pin);
  }

  // Verify PIN in background — UI stays responsive
  static Future<bool> verifyPin(String pin, String storedHash) async {
    return compute(_verifyPinIsolate, [pin, storedHash]);
  }

  // Check if a phone number is already registered
  static Future<bool> phoneExists(String phone) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return data != null;
  }

  // Register a new farmer
  static Future<String> register({
    required String name,
    required String barangay,
    required String phone,
    required String pin,
    required List<String> cropsGrown,
    double? latitude,
    double? longitude,
  }) async {
    // Hash PIN in background isolate — won't freeze the UI
    final pinHash = await hashPin(pin);

    // Insert farmer record into Supabase
    final response = await Supabase.instance.client
        .from('farmers')
        .insert({
          'name': name,
          'barangay': barangay,
          'phone': phone,
          'pin_hash': pinHash,
          'crops_grown': cropsGrown,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select('id')
        .single();

    final farmerId = response['id'] as String;
    await saveLocalFarmerId(farmerId);
    return farmerId;
  }

  // ── LOCAL SESSION ─────────────────────────────────────────

  static Future<void> saveLocalFarmerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_farmerIdKey, id);
  }

  static Future<String?> getLocalFarmerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_farmerIdKey);
  }

  static Future<Map<String, dynamic>?> getLocalFarmer() async {
    final id = await getLocalFarmerId();
    if (id == null) return null;
    return Supabase.instance.client
        .from('farmers')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  static Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_farmerIdKey);
  }
}
