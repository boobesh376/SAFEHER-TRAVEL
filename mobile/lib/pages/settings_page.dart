import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class SettingsPage extends StatefulWidget {
  final VoidCallback onLogout;
  const SettingsPage({super.key, required this.onLogout});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _profile;
  List<dynamic> _contacts = [];
  bool _loadingProfile = true;

  static const _purple = Color(0xFF5D3891);
  static const _red    = Color(0xFFE71C23);
  static const _grey   = Color(0xFF8E8E93);
  static const _bg     = Color(0xFFF2F2F7);
  static const _dark   = Color(0xFF1F1F1F);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final res = await _api.getProfile();
      final cRes = await _api.getEmergencyContacts();
      if (mounted) {
        setState(() {
          _profile  = res['success'] == true ? res['profile'] : null;
          _contacts = cRes['success'] == true ? (cRes['contacts'] ?? []) : [];
          _loadingProfile = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProfile = false);
    }
  }

  // ─── Change Password Dialog ────────────────────────────────────────────────

  void _showChangePasswordDialog() {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Change Password',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(error!, style: const TextStyle(color: _red, fontSize: 13)),
                ),
              _field(oldCtrl, 'Current Password', Icons.lock_outline_rounded, isPassword: true),
              const SizedBox(height: 12),
              _field(newCtrl, 'New Password (min 8 chars)', Icons.lock_person_outlined, isPassword: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: _grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (oldCtrl.text.isEmpty || newCtrl.text.isEmpty) {
                  setDState(() => error = 'Both fields are required');
                  return;
                }
                if (newCtrl.text.length < 8) {
                  setDState(() => error = 'New password must be at least 8 characters');
                  return;
                }
                final res = await _api.changePassword(
                  oldPassword: oldCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _showSnack(res['success'] == true
                      ? '✅ Password updated successfully'
                      : (res['error'] ?? 'Password change failed'));
                }
              },
              child: const Text('Update'),
            ),
          ],
        );
      }),
    );
  }

  // ─── Add Contact Dialog ───────────────────────────────────────────────────

  void _showAddContactDialog() {
    final nameCtrl  = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Emergency Contact',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(nameCtrl,  'Contact Name',   Icons.person_outline_rounded),
            const SizedBox(height: 12),
            _field(phoneCtrl, 'Phone Number',   Icons.phone_outlined,
                type: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: _grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _purple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) return;
              final res = await _api.addEmergencyContact(
                contactName:  nameCtrl.text.trim().isEmpty ? 'Emergency Contact' : nameCtrl.text.trim(),
                contactPhone: phoneCtrl.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (res['success'] == true) {
                _loadProfile();
                if (mounted) _showSnack('✅ Contact added');
              } else {
                if (mounted) _showSnack(res['error'] ?? 'Failed to add contact');
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteContact(String contactId) async {
    final res = await _api.deleteEmergencyContact(contactId);
    if (res['success'] == true) {
      _loadProfile();
      if (mounted) _showSnack('Contact removed');
    } else {
      if (mounted) _showSnack(res['error'] ?? 'Failed to remove contact');
    }
  }

  void _logout() async {
    await AuthService.logout();
    widget.onLogout();
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 32, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Settings',
            style: TextStyle(color: _dark, fontWeight: FontWeight.w900, fontSize: 20)),
      ),
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: _purple))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ── Profile card ──────────────────────────────────────────
                _sectionHeader('Account'),
                _card([
                  _profileRow(
                    Icons.person_rounded,
                    _profile?['name'] ?? '—',
                    subtitle: _profile?['email'] ?? '—',
                  ),
                  if ((_profile?['phone'] ?? '').isNotEmpty)
                    _profileRow(Icons.phone_rounded, _profile!['phone']),
                  if ((_profile?['city'] ?? '').isNotEmpty)
                    _profileRow(Icons.location_on_rounded, _profile!['city']),
                ]),

                const SizedBox(height: 20),

                // ── Security ──────────────────────────────────────────────
                _sectionHeader('Security'),
                _card([
                  _tileButton(
                    Icons.lock_outline_rounded,
                    'Change Password',
                    onTap: _showChangePasswordDialog,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Emergency Contacts ────────────────────────────────────
                _sectionHeader('Emergency Contacts (${_contacts.length})'),
                _card([
                  if (_contacts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Text('No emergency contacts added yet.',
                          style: TextStyle(color: _grey, fontSize: 13)),
                    ),
                  ..._contacts.map((c) => _contactRow(c)),
                  _tileButton(
                    Icons.add_circle_outline_rounded,
                    'Add Emergency Contact',
                    iconColor: _purple,
                    onTap: _showAddContactDialog,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── App Info ──────────────────────────────────────────────
                _sectionHeader('App Info'),
                _card([
                  _tileButton(
                    Icons.info_outline_rounded,
                    'Version 1.0.0',
                    trailing: const SizedBox.shrink(),
                    onTap: () {},
                  ),
                  _tileButton(
                    Icons.privacy_tip_outlined,
                    'Privacy Policy',
                    onTap: () async {
                      final url = Uri.parse('https://safeher.app/privacy');
                      try {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      } catch (_) {}
                    },
                  ),
                ]),

                const SizedBox(height: 20),

                // ── Logout ───────────────────────────────────────────────
                GestureDetector(
                  onTap: () => showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: const Text('Logout',
                          style: TextStyle(fontWeight: FontWeight.w900)),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _logout();
                          },
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  ),
                  child: Container(
                    height: 54,
                    decoration: BoxDecoration(
                      color: _red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _red.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout_rounded, color: _red, size: 20),
                        SizedBox(width: 10),
                        Text('Logout',
                            style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w800,
                                fontSize: 15)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  // ─── UI Helpers ────────────────────────────────────────────────────────────

  Widget _sectionHeader(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                color: _grey, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: children.asMap().entries.map((e) {
            final isLast = e.key == children.length - 1;
            return Column(
              children: [
                e.value,
                if (!isLast)
                  Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.08),
                      indent: 52, endIndent: 16),
              ],
            );
          }).toList(),
        ),
      );

  Widget _profileRow(IconData icon, String text, {String? subtitle}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: _purple, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(text,
                      style: const TextStyle(
                          color: _dark, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(color: _grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tileButton(IconData icon, String label,
      {required VoidCallback onTap,
      Color iconColor = const Color(0xFF5D3891),
      Widget? trailing}) =>
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                        color: _dark, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
              trailing ??
                  const Icon(Icons.chevron_right_rounded, color: _grey, size: 20),
            ],
          ),
        ),
      );

  Widget _contactRow(Map contact) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.contact_emergency_outlined,
                  color: Colors.green, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact['contact_name'] ?? 'Emergency Contact',
                      style: const TextStyle(
                          color: _dark, fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(contact['contact_phone'] ?? '',
                      style: const TextStyle(color: _grey, fontSize: 12)),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded,
                  color: _red, size: 20),
              onPressed: () => _deleteContact(contact['id']),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {bool isPassword = false, TextInputType? type}) =>
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: isPassword,
          keyboardType: type,
          style: const TextStyle(color: _dark, fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(color: _grey, fontSize: 13),
            prefixIcon: Icon(icon, color: _grey, size: 18),
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      );
}
