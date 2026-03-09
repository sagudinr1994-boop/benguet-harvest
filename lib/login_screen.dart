import 'dart:async';
import 'package:flutter/material.dart';
import 'auth_service.dart';
import 'biometric_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl   = TextEditingController();

  bool    _isLoading       = false;
  String? _errorMsg;

  // Rate-limiting
  int    _failedAttempts  = 0;
  bool   _isLocked        = false;
  int    _lockSecondsLeft = 0;
  Timer? _lockTimer;

  // Biometric
  bool _biometricAvailable = false;
  bool _hasSavedFarmer     = false;  // true if farmer ever logged in before
  bool _showPinForm        = false;

  @override
  void initState() {
    super.initState();
    _checkAndPromptBiometric();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  // ── BIOMETRIC ─────────────────────────────────────────────

  Future<void> _checkAndPromptBiometric() async {
    final available  = await BiometricService.isAvailable();
    final savedId    = await AuthService.getSavedFarmerId(); // survives logout

    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _hasSavedFarmer     = savedId != null;
    });

    // Auto-prompt only if device supports biometrics AND farmer was seen before
    if (available && savedId != null) {
      final ok = await BiometricService.authenticate();
      if (ok) {
        final success = await AuthService.biometricLogin();
        if (success && mounted) {
          Navigator.of(context).pop('logged_in');
          return;
        }
      }
    }

    if (mounted) setState(() => _showPinForm = true);
  }

  // ── RATE LIMITING ─────────────────────────────────────────

  void _startLockout() {
    setState(() {
      _isLocked        = true;
      _lockSecondsLeft = 30;
    });
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _lockSecondsLeft--);
      if (_lockSecondsLeft <= 0) {
        timer.cancel();
        setState(() {
          _isLocked       = false;
          _failedAttempts = 0;
        });
      }
    });
  }

  // ── PIN LOGIN ─────────────────────────────────────────────

  Future<void> _attemptLogin() async {
    if (_isLocked) return;

    final phone = _phoneCtrl.text.trim();
    final pin   = _pinCtrl.text.trim();

    if (phone.length < 11) {
      setState(() => _errorMsg = 'Enter your 11-digit mobile number.');
      return;
    }
    if (pin.length != 6) {
      setState(() => _errorMsg = 'PIN must be 6 digits.');
      return;
    }

    setState(() { _isLoading = true; _errorMsg = null; });

    try {
      final farmer = await AuthService.login(phone: phone, pin: pin);

      if (farmer != null) {
        if (mounted) Navigator.of(context).pop('logged_in');
      } else {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _startLockout();
          setState(() {
            _isLoading = false;
            _errorMsg  = 'Too many attempts. Wait 30 seconds.';
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMsg  = 'Incorrect phone number or PIN. '
                '${3 - _failedAttempts} attempt(s) remaining.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg  = 'Connection error. Check internet and try again.';
      });
    }
  }

  // ── BIOMETRIC BUTTON ACTION ───────────────────────────────

  Future<void> _tryBiometric() async {
    setState(() => _errorMsg = null);

    if (!_hasSavedFarmer) {
      setState(() =>
        _errorMsg = 'Please log in with PIN first to enable biometrics.');
      return;
    }

    final ok = await BiometricService.authenticate();
    if (ok) {
      final success = await AuthService.biometricLogin();
      if (success && mounted) {
        Navigator.of(context).pop('logged_in');
      } else if (mounted) {
        setState(() => _errorMsg = 'Could not restore session. Try PIN.');
      }
    } else if (mounted) {
      setState(() => _errorMsg = 'Biometric not recognised. Try your PIN.');
    }
  }

  // ── BUILD ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2EDE6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C3A28),
        iconTheme: const IconThemeData(color: Color(0xFFE8B84B)),
        title: const Text('Log In',
          style: TextStyle(
            color: Color(0xFFE8B84B),
            fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: _showPinForm
            ? _buildPinForm()
            : _buildBiometricWait(),
      ),
    );
  }

  // ── FINGERPRINT WAITING SCREEN ────────────────────────────

  Widget _buildBiometricWait() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.fingerprint, size: 96, color: Color(0xFF2D5A3D)),
        const SizedBox(height: 24),
        const Text('Touch the fingerprint sensor',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1C3A28))),
        const SizedBox(height: 8),
        const Text('or use Face ID to log in',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        TextButton.icon(
          icon: const Icon(Icons.pin, color: Color(0xFF2D5A3D)),
          label: const Text('Use PIN instead',
            style: TextStyle(color: Color(0xFF2D5A3D))),
          onPressed: () => setState(() => _showPinForm = true),
        ),
      ]),
    ));
  }

  // ── PIN FORM ──────────────────────────────────────────────

  Widget _buildPinForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_open_outlined,
            size: 56, color: Color(0xFF2D5A3D)),
          const SizedBox(height: 16),
          const Text('Welcome back',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1C3A28))),
          const Text('Enter your mobile number and PIN.',
            style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),

          // Phone field
          TextField(
            controller: _phoneCtrl,
            keyboardType: TextInputType.phone,
            enabled: !_isLocked,
            decoration: const InputDecoration(
              labelText: 'Mobile Number',
              hintText: '09XXXXXXXXX',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // PIN field
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            enabled: !_isLocked,
            decoration: const InputDecoration(
              labelText: 'PIN',
              prefixIcon: Icon(Icons.lock_outline),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Error message
          if (_errorMsg != null)
            Text(_errorMsg!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold)),

          // Lockout countdown
          if (_isLocked)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Try again in $_lockSecondsLeft seconds...',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold)),
            ),

          const SizedBox(height: 24),

          // Biometric button — shown when hardware available
          if (_biometricAvailable) ...[
            SizedBox(width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.fingerprint,
                  color: Color(0xFF2D5A3D)),
                label: const Text('Use Fingerprint / Face ID',
                  style: TextStyle(color: Color(0xFF2D5A3D))),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF2D5A3D)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _tryBiometric,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Log In button
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isLocked
                    ? Colors.grey
                    : const Color(0xFF1C3A28),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: (_isLoading || _isLocked) ? null : _attemptLogin,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : _isLocked
                      ? Text('Locked ($_lockSecondsLeft s)',
                          style: const TextStyle(fontSize: 16))
                      : const Text('Log In',
                          style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}