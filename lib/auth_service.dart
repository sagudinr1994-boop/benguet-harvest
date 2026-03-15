import 'package:bcrypt/bcrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Email-based auth (Supabase Auth) ────────────────────────────────────────
// New users register with email + PIN.
// Supabase Auth sends a confirmation email; user confirms once then logs in.
// Existing phone-based users are unaffected (biometric still works).
// ─────────────────────────────────────────────────────────────────────────────

class AuthService {
  static const String _farmerIdKey = 'farmer_id';
  static const String _loggedInKey = 'logged_in';
  static const String _roleKey = 'farmer_role';

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

  static Future<bool> emailExists(String email) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select('id')
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    return data != null;
  }

  // ── EMAIL REGISTRATION (Supabase Auth) ───────────────────────────────────

  /// Creates a Supabase Auth user (sends confirmation email) then inserts the
  /// farmers row. Returns farmer data. Does NOT mark logged_in = true — the
  /// user must confirm their email then log in.
  static Future<Map<String, dynamic>> registerWithEmail({
    required String name,
    required String barangay,
    required String email,
    required String pin,
    required List<String> cropsGrown,
    double? latitude,
    double? longitude,
  }) async {
    final authResponse = await Supabase.instance.client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: pin,
    );
    if (authResponse.user == null) throw Exception('Auth signup failed');

    final pinHash = hashPin(pin);
    final farmerData = await Supabase.instance.client
        .from('farmers')
        .insert({
          'name': name,
          'barangay': barangay,
          'email': email.trim().toLowerCase(),
          'auth_id': authResponse.user!.id,
          'pin_hash': pinHash,
          'crops_grown': cropsGrown,
          'latitude': latitude,
          'longitude': longitude,
        })
        .select('id, role')
        .single();

    return farmerData;
  }

  // ── EMAIL LOGIN (Supabase Auth) ────────────────────────────────────────────

  /// Signs in with email + PIN via Supabase Auth, then fetches the farmer row.
  /// Throws [AuthException] on bad credentials or unconfirmed email.
  static Future<Map<String, dynamic>?> loginWithEmail({
    required String email,
    required String pin,
  }) async {
    final authResponse = await Supabase.instance.client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: pin,
    );
    if (authResponse.session == null) return null;

    final data = await Supabase.instance.client
        .from('farmers')
        .select()
        .eq('auth_id', authResponse.user!.id)
        .maybeSingle();
    if (data == null) return null;

    await saveLocalFarmerId(data['id'] as String);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_roleKey, data['role'] as String? ?? 'farmer');
    await _setLoggedIn(true);
    return data;
  }

  // ── CHANGE PIN (email-auth users) ─────────────────────────────────────────

  static Future<bool> changePinEmail({
    required String farmerId,
    required String currentPin,
    required String newPin,
  }) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select('pin_hash')
        .eq('id', farmerId)
        .single();
    final storedHash = data['pin_hash'] as String? ?? '';
    if (!verifyPin(currentPin, storedHash)) return false;

    await Supabase.instance.client.auth.updateUser(
      UserAttributes(password: newPin),
    );
    await Supabase.instance.client
        .from('farmers')
        .update({'pin_hash': hashPin(newPin)})
        .eq('id', farmerId);
    return true;
  }

  // ── RESEND CONFIRMATION EMAIL ─────────────────────────────────────────────

  static Future<void> resendConfirmation(String email) async {
    await Supabase.instance.client.auth.resend(
      type: OtpType.signup,
      email: email.trim().toLowerCase(),
    );
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
    await _setLoggedIn(true);
    return farmerId;
  }

  static Future<void> saveLocalFarmerId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_farmerIdKey, id);
  }

  // Returns farmer ID only if the user is currently logged in
  static Future<String?> getLocalFarmerId() async {
    final prefs = await SharedPreferences.getInstance();
    final loggedIn = prefs.getBool(_loggedInKey) ?? false;
    if (!loggedIn) return null;
    return prefs.getString(_farmerIdKey);
  }

  // Returns farmer ID regardless of login state (used for biometric login)
  static Future<String?> getSavedFarmerId() async {
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

  // Get the logged-in farmer's role
  static Future<String> getLocalRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey) ?? 'farmer';
  }

  static Future<void> _setLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, value);
  }

  // Logout: clears session flag and role, but KEEPS farmer ID so biometrics still work
  static Future<void> logOut() async {
    final prefs = await SharedPreferences.getInstance();
    await _setLoggedIn(false);
    await prefs.remove(_roleKey);
    // farmer_id is intentionally kept — biometric login needs it
  }

  // ── LOGIN ─────────────────────────────────────────────────

  static Future<Map<String, dynamic>?> login({
    required String phone,
    required String pin,
  }) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select()
        .eq('phone', phone)
        .maybeSingle();

    if (data == null) return null;

    final storedHash = data['pin_hash'] as String? ?? '';
    final pinOk = verifyPin(pin, storedHash);
    if (!pinOk) return null;

    final prefs = await SharedPreferences.getInstance();
    await saveLocalFarmerId(data['id'] as String);
    await prefs.setString(_roleKey, data['role'] as String? ?? 'farmer');
    await _setLoggedIn(true);
    return data;
  }

  // ── BIOMETRIC LOGIN ───────────────────────────────────────

  // Called after successful biometric auth — restores the session and role
  static Future<bool> biometricLogin() async {
    final id = await getSavedFarmerId();
    if (id == null) return false;

    // Re-fetch role from Supabase so encoder/admin access is restored
    try {
      final data = await Supabase.instance.client
          .from('farmers')
          .select('role')
          .eq('id', id)
          .maybeSingle();
      if (data != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_roleKey, data['role'] as String? ?? 'farmer');
      }
    } catch (_) {
      // If offline, role stays as whatever was last cached (default: farmer)
    }

    await _setLoggedIn(true);
    return true;
  }

  // ── CHANGE PIN ────────────────────────────────────────────

  static Future<bool> changePin({
    required String farmerId,
    required String currentPin,
    required String newPin,
  }) async {
    final data = await Supabase.instance.client
        .from('farmers')
        .select('pin_hash')
        .eq('id', farmerId)
        .single();

    final storedHash = data['pin_hash'] as String? ?? '';
    if (!verifyPin(currentPin, storedHash)) return false;

    final newHash = hashPin(newPin);
    await Supabase.instance.client
        .from('farmers')
        .update({'pin_hash': newHash})
        .eq('id', farmerId);

    return true;
  }
}
