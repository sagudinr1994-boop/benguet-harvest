import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

// BiometricService — wraps local_auth for fingerprint login
class BiometricService {
  static final _auth = LocalAuthentication();
  static const _prefKey = 'biometric_enabled';

  // ── AVAILABILITY ─────────────────────────────────────────

  // Returns true if the device has a working biometric sensor
  // AND at least one fingerprint (or face) is enrolled
  static Future<bool> isAvailable() async {
    try {
      // Can the device do biometrics at all?
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

      // Is at least one biometric enrolled?
      final available = await _auth.getAvailableBiometrics();
      return available.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ── AUTHENTICATION ───────────────────────────────────────

  // Show the biometric prompt and return true if authenticated
  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Place your finger on the sensor to log in',
        options: const AuthenticationOptions(
          biometricOnly: false, // allow PIN fallback from OS dialog
          stickyAuth: true, // keep prompt open if app goes background
          useErrorDialogs: true, // show system error messages
        ),
      );
    } catch (_) {
      return false; // any error = not authenticated
    }
  }

  // ── PREFERENCE ───────────────────────────────────────────

  // Is biometric login enabled on this device?
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_prefKey) ?? false;
  }

  // Enable or disable biometric login on this device
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
  }

  // Clear biometric preference (called on log out)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }
}
