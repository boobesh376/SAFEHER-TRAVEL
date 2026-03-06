import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// Pull brand colors from login_page.dart scope (or redefine here)
class _Brand {
  static const primaryPink  = Color(0xFFE91E8C);
  static const lavender     = Color(0xFFCE93D8);
  static const deepLavender = Color(0xFF9C27B0);
  static const paleLavender = Color(0xFFF3E5F5);
  static const textDark     = Color(0xFF2D1B2E);
  static const textMuted    = Color(0xFF9E7BA0);
  static const surface      = Color(0xFFFFF8FC);
}

class SignupPage extends StatefulWidget {
  final VoidCallback onSignupSuccess;
  const SignupPage({super.key, required this.onSignupSuccess});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final ApiService _api = ApiService();
  bool _loading    = false;
  bool _showPass   = false;
  String? _error;

  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _phoneCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _healthCtrl = TextEditingController();
  bool _consentAgreed = false;
  final List<TextEditingController> _contactCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose(); _phoneCtrl.dispose();
    _passCtrl.dispose(); _cityCtrl.dispose(); _healthCtrl.dispose();
    for (final c in _contactCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _register() async {
    final name  = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final pass  = _passCtrl.text;
    final city  = _cityCtrl.text.trim();

    if (name.isEmpty)  { setState(() => _error = 'Please enter your full name'); return; }
    if (email.isEmpty) { setState(() => _error = 'Please enter your email address'); return; }
    if (!email.contains('@')) { setState(() => _error = 'Please enter a valid email address'); return; }
    if (phone.isEmpty) { setState(() => _error = 'Please enter your mobile number'); return; }
    if (pass.isEmpty)  { setState(() => _error = 'Please create a password'); return; }
    if (city.isEmpty)  { setState(() => _error = 'Please enter your city'); return; }

    final contacts = _contactCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (contacts.isEmpty) {
      setState(() => _error = 'Please add at least one emergency contact number');
      return;
    }
    if (!_consentAgreed) {
      setState(() => _error = 'Please agree to the safety compliance terms');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final res = await _api.register(
      name: name, email: email, phone: phone,
      password: pass, city: city,
      emergencyContacts: contacts,
      healthConditions: _healthCtrl.text.trim(),
      consentAgreed: _consentAgreed,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        if (mounted) Navigator.of(context).pop();
        widget.onSignupSuccess();
      } else {
        setState(() => _error = res['error'] ?? 'Registration failed. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Brand.surface,
      body: Column(
        children: [
          // ── Gradient header with logo ──
          _buildHeader(context),

          // ── Form ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create Account', style: TextStyle(
                    color: _Brand.textDark, fontSize: 24, fontWeight: FontWeight.w800,
                  )),
                  const SizedBox(height: 4),
                  Text('Complete your profile to get started', style: TextStyle(
                    color: _Brand.textMuted, fontSize: 14,
                  )),
                  const SizedBox(height: 28),

                  _section('Personal Details'),
                  const SizedBox(height: 14),
                  _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
                  const SizedBox(height: 12),
                  _field(_emailCtrl, 'Email Address', Icons.email_outlined, type: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(_phoneCtrl, 'Mobile Number', Icons.phone_android_rounded, type: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(_passCtrl, 'Password', Icons.lock_outline_rounded, isPassword: true),
                  const SizedBox(height: 12),
                  _field(_cityCtrl, 'Home City / Current City', Icons.location_on_outlined),

                  const SizedBox(height: 28),
                  _section('Emergency Contacts'),
                  const SizedBox(height: 6),
                  Text(
                    'They will receive an SOS alert with your live location if you trigger an emergency.',
                    style: TextStyle(color: _Brand.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  ..._contactCtrls.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _field(e.value,
                      'Contact ${e.key + 1}${e.key == 0 ? ' (Required)' : ' (Optional)'}',
                      Icons.contact_emergency_outlined, type: TextInputType.phone),
                  )),

                  const SizedBox(height: 28),
                  _section('Health Info (Optional)'),
                  const SizedBox(height: 14),
                  _field(_healthCtrl, 'Any health conditions to note', Icons.medical_services_outlined),

                  const SizedBox(height: 24),
                  // Consent checkbox
                  InkWell(
                    onTap: () => setState(() => _consentAgreed = !_consentAgreed),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _consentAgreed ? _Brand.paleLavender : _Brand.paleLavender.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _consentAgreed ? _Brand.deepLavender : _Brand.lavender.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _consentAgreed ? Icons.check_circle_rounded : Icons.circle_outlined,
                            color: _consentAgreed ? _Brand.deepLavender : _Brand.lavender,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'I agree to SafeHer\'s user agreement and safety compliance terms',
                              style: TextStyle(
                                color: _Brand.textDark, fontSize: 13, fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  if (_error != null) _errorBox(_error!),

                  _registerButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      height: 160,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9C27B0), Color(0xFFE91E8C), Color(0xFFF48FB1)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/images/safeher_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SafeHer', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                Text('Join the safety network', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String label) {
    return Row(
      children: [
        Container(width: 3, height: 16, decoration: BoxDecoration(
          color: _Brand.primaryPink, borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: _Brand.textDark, fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {TextInputType? type, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(
        color: _Brand.paleLavender,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _Brand.lavender.withOpacity(0.3)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: isPassword && !_showPass,
        style: TextStyle(color: _Brand.textDark, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: _Brand.textMuted, fontSize: 13),
          prefixIcon: Icon(icon, color: _Brand.lavender, size: 19),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(_showPass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                color: _Brand.lavender, size: 18),
            onPressed: () => setState(() => _showPass = !_showPass),
          ) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _errorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline, color: Color(0xFFC62828), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFC62828), fontSize: 13))),
      ]),
    );
  }

  Widget _registerButton() {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFFE91E8C)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: _Brand.primaryPink.withOpacity(0.35), blurRadius: 16, offset: const Offset(0, 6),
        )],
      ),
      child: ElevatedButton(
        onPressed: _loading ? null : _register,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : const Text('Create My Account', style: TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
