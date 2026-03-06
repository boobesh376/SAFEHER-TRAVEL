import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  final VoidCallback onSignupSuccess;
  const SignupPage({super.key, required this.onSignupSuccess});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final ApiService _api = ApiService();
  bool _loading = false;
  String? _error;

  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _healthCtrl = TextEditingController();
  bool _consentAgreed = false;
  final List<TextEditingController> _contactCtrls = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _cityCtrl.dispose();
    for (final c in _contactCtrls) { c.dispose(); }
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final password = _passCtrl.text;
    final city = _cityCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your full name');
      return;
    }
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email address');
      return;
    }
    if (phone.isEmpty) {
      setState(() => _error = 'Please enter your mobile number');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (city.isEmpty) {
      setState(() => _error = 'Please enter your home city');
      return;
    }

    if (!email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }

    final contacts = _contactCtrls.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (contacts.isEmpty) {
      setState(() => _error = 'Please add at least one emergency contact number');
      return;
    }

    if (!_consentAgreed) {
      setState(() => _error = 'You must agree to the user consent & safety compliance');
      return;
    }

    setState(() { _loading = true; _error = null; });

    // api_service.register() saves the JWT session automatically
    final res = await _api.register(
      name: name,
      email: email,
      phone: phone,
      password: password,
      city: city,
      emergencyContacts: contacts,
      healthConditions: _healthCtrl.text.trim(),
      consentAgreed: _consentAgreed,
    );

    if (mounted) {
      setState(() => _loading = false);
      if (res['success'] == true) {
        // Pop signup page from navigation stack before triggering success
        if (mounted) Navigator.of(context).pop();
        widget.onSignupSuccess();
      } else {
        setState(() => _error = res['error'] ?? 'Registration failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1F1F1F), size: 32),
        ),
        title: const Text('Create Account', style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Join SafeHer',
                style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
              ),
              const SizedBox(height: 8),
              const Text(
                'Complete your profile to get started with full protection.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 32),
              
              _sectionLabel('Personal Details'),
              const SizedBox(height: 16),
              _buildField(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
              const SizedBox(height: 16),
              _buildField(_emailCtrl, 'Email Address', Icons.email_outlined, TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildField(_phoneCtrl, 'Mobile Number', Icons.phone_android_rounded, TextInputType.phone),
              const SizedBox(height: 16),
              _buildField(_passCtrl, 'Password', Icons.lock_outline_rounded, null, true),
              const SizedBox(height: 16),
              _buildField(_cityCtrl, 'Home City', Icons.location_on_outlined),
              const SizedBox(height: 32),

              _sectionLabel('Emergency Shield'),
              const SizedBox(height: 8),
              const Text(
                'These contacts will receive SOS alerts with your live location.',
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              ..._contactCtrls.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildField(e.value, 'Contact ${e.key + 1}${e.key == 0 ? ' (Required)' : ''}',
                    Icons.contact_emergency_outlined, TextInputType.phone),
              )),

              const SizedBox(height: 32),
              _sectionLabel('Health & Safety'),
              const SizedBox(height: 16),
              _buildField(_healthCtrl, 'Health Conditions (Optional)', Icons.medical_services_outlined),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: _consentAgreed,
                    activeColor: const Color(0xFF5D3891),
                    onChanged: (val) => setState(() => _consentAgreed = val ?? false),
                  ),
                  const Expanded(
                    child: Text(
                      'I agree to the user agreement & safety compliance terms.',
                      style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              if (_error != null) _buildErrorBox(_error!),

              const SizedBox(height: 8),
              _buildPrimaryButton(
                label: _loading ? 'Registering...' : 'Complete Registration',
                onTap: _loading ? null : _register,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(label, style: const TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.w900, fontSize: 16));
  }

  Widget _buildErrorBox(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE71C23).withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE71C23).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFE71C23), size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFFE71C23), fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController ctrl, String label, IconData icon,
      [TextInputType? type, bool isPassword = false]) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: isPassword,
        style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, color: const Color(0xFF5D3891), size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF5D3891),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D3891).withOpacity(0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
