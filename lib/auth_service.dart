import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// AuthService — manages farmer identity on this device
// Handles registration, PIN hashing, and local session storage
class AuthService {
  // Key used to store the logged-in farmer's ID on device
  static const String _farmerIdKey = 'farmer_id';

  // ── REGISTRATION ─────────────────────────────────────────

  // Hash a 6-digit PIN using bcrypt
  // The hash is a long string that cannot be reversed back to the PIN
  static String hashPin(String pin) {
    final salt = BCrypt.gensalt(logRounds: 10);
    return BCrypt.hashpw(pin, salt);
  }

  // Verify a PIN against a stored hash
  // Returns true if the PIN matches — used at login (Day 10)
  static bool verifyPin(String pin, String storedHash) {
    return BCrypt.checkpw(pin, storedHash);
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

  // Register a new farmer — saves to Supabase and stores ID locally
  static Future<String> register({
    required String name,
    required String barangay,
    required String phone,
    required String pin,
    required List<String> cropsGrown,
    double? latitude,
    double? longitude,
  }) async {
    // 1. Hash the PIN before storing
    final pinHash = hashPin(pin);

    // 2. Insert the farmer record into Supabase
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
        .select('id') // return the new farmer's ID
        .single();

    final farmerId = response['id'] as String;

    // 3. Save the farmer ID on this device so they stay logged in
    await saveLocalFarmerId(farmerId);
    return farmerId;
  }

  // ── LOCAL SESSION ─────────────────────────────────────────

  // Save the farmer's ID on the device (persists across app restarts)
  static Future<void> saveLocalFarmerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_farmerIdKey, id);
  }

  // Get the locally stored farmer ID (null if not registered)
  static Future<String?> getLocalFarmerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_farmerIdKey);
  }

  // Load full farmer data from Supabase using stored ID
  static Future<Map<String, dynamic>?> getLocalFarmer() async {
    final id = await getLocalFarmerId();
    if (id == null) return null;
    return Supabase.instance.client
        .from('farmers')
        .select()
        .eq('id', id)
        .maybeSingle();
  }

  // Clear the local session (log out)
  static Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_farmerIdKey);
  }
}
