import 'package:local_auth/local_auth.dart';

// BiometricService — wraps local_auth for fingerprint / face login
// No preference needed: button always shows if hardware is available.
class BiometricService {
  static final _auth = LocalAuthentication();

  // ── AVAILABILITY ─────────────────────────────────────────

  // Returns true if the device has a working biometric sensor
  // AND at least one fingerprint (or face) is enrolled
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;

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
    } catch (e) {
      print('DEBUG biometric error: $e');
      return false; // fail gracefully — falls back to PIN
    }
  }
}
