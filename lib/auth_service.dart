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
}
