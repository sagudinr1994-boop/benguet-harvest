import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static const String _farmerIdKey = 'farmer_id';

  // logRounds: 4 is fast enough to not freeze (takes ~10ms)
  // Change back to 10 before releasing to real phones
  static const int _bcryptRounds = 4;

  static String hashPin(String pin) {
    final salt = BCrypt.gensalt(logRounds: _bcryptRounds);
    return BCrypt.hashpw(pin, salt);
  }

  static bool verifyPin(String pin, String storedHash) {
    return BCrypt.checkpw(pin, storedHash);
  }

  static Future<bool> phoneExists(String phone) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select('id')
        .eq('phone', phone)
        .maybeSingle();
    return data != null;
  }

  static Future<String> register({
    required String name,
    required String barangay,
    required String phone,
    required String pin,
    required List<String> cropsGrown,
    double? latitude,
    double? longitude,
  }) async {
    final pinHash = hashPin(pin);

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
  // ── LOGIN ─────────────────────────────────────────────────

  // Find farmer by phone number and verify PIN
  // Returns farmer map on success, null on failure
  static Future<Map<String, dynamic>?> login({
    required String phone,
    required String pin,
  }) async {
    // 1. Look up farmer by phone number
    final data = await Supabase.instance.client
        .from('farmers')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (data == null) return null; // phone not found

    // 2. Verify the PIN against the stored hash
    final storedHash = data['pin_hash'] as String? ?? '';
    final pinOk = verifyPin(pin, storedHash);

    if (!pinOk) return null; // wrong PIN

    // 3. Save the farmer ID locally (same as after registration)
    await saveLocalFarmerId(data['id'] as String);
    return data;
  }

  // ── CHANGE PIN ──────────────────────────────────────────

  // Verify current PIN, then update to new PIN
  static Future<bool> changePin({
    required String farmerId,
    required String currentPin,
    required String newPin,
  }) async {
    // 1. Fetch current hash
    final data = await Supabase.instance.client
        .from('farmers')
        .select('pin_hash')
        .eq('id', farmerId)
        .single();

    final storedHash = data['pin_hash'] as String? ?? '';
    if (!verifyPin(currentPin, storedHash)) return false;

    // 2. Hash the new PIN and update
    final newHash = hashPin(newPin);
    await Supabase.instance.client
        .from('farmers')
        .update({'pin_hash': newHash})
        .eq('id', farmerId);

    return true; // success
  }
}
