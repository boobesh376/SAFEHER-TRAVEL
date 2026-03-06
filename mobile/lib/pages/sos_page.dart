import 'package:flutter/material.dart';
import 'dart:async';
import '../services/location_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class SOSPage extends StatefulWidget {
  const SOSPage({super.key});

  @override
  State<SOSPage> createState() => _SOSPageState();
}

class _SOSPageState extends State<SOSPage> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();
  final ApiService _apiService = ApiService();
  bool _isActivating = false;
  bool _isTriggered = false;
  Map<String, dynamic>? _sosResponse;
  int _countdown = 5;
  Timer? _timer;
  int _etaSeconds = 1800; // 30 mins
  Timer? _etaTimer;
  Timer? _liveLocationTimer; // Live location updates every 30s
  Position? _currentPosition;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Real user data from session
  String _userId = '';
  String _userName = '';
  List<String> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
    _updateLocation();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = await AuthService.getUser();
    if (user != null && mounted) {
      setState(() {
        _userId = user['id'] ?? '';
        _userName = user['name'] ?? '';
        final contacts = user['emergency_contacts'];
        if (contacts is List) {
          _emergencyContacts = contacts.map((c) => c.toString()).where((c) => c.isNotEmpty).toList();
        }
      });
    }
  }

  Future<void> _updateLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _currentPosition = pos);
  }

  void _startCountdown() {
    setState(() { _isActivating = true; _countdown = 5; });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _activateSOS();
      }
    });
  }

  void _cancelSOS() {
    _timer?.cancel();
    setState(() { _isActivating = false; _countdown = 5; });
  }

  void _activateSOS() async {
    final pos = _currentPosition ?? await _locationService.getCurrentLocation();
    if (pos != null) {
      final res = await _apiService.triggerSOS(
        lat: pos.latitude,
        lng: pos.longitude,
      );
      if (mounted) {
        setState(() { 
          _isTriggered = true; 
          _isActivating = false;
          _sosResponse = res;
          _startEtaTimer();
          _startLiveLocationUpdates(res['sos_id'] as String?);
        });
        // Send WhatsApp messages to emergency contacts
        _sendWhatsAppAlerts(pos);
      }
    }
  }

  Future<void> _sendWhatsAppAlerts(Position pos) async {
    final mapLink = 'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';
    final message = Uri.encodeComponent(
      'EMERGENCY ALERT from SafeHer!\n\n'
      '${_userName.isNotEmpty ? _userName : "Your contact"} has activated an SOS alert and needs immediate help!\n\n'
      'Location: $mapLink\n\n'
      'Please contact them immediately or call emergency services.\n'
      'Police: 100 | Emergency: 112 | Women Helpline: 1091'
    );
    for (final contact in _emergencyContacts) {
      // Clean phone number — remove spaces, dashes
      final cleanPhone = contact.replaceAll(RegExp(r'[\s\-()]'), '');
      // Add country code if not present
      final phone = cleanPhone.startsWith('+') ? cleanPhone : '+91$cleanPhone';
      final waUrl = Uri.parse('https://wa.me/${phone.replaceAll("+", "")}?text=$message');
      try {
        await launchUrl(waUrl, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('WhatsApp launch failed for $contact: $e');
      }
    }
  }

  void _startEtaTimer() {
    _etaTimer?.cancel();
    _etaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_etaSeconds > 0) {
        setState(() => _etaSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  String _formatTime(int seconds) {
    int m = seconds ~/ 60;
    int s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    _etaTimer?.cancel();
    _liveLocationTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  /// Send live GPS updates every 30 seconds while SOS is active
  void _startLiveLocationUpdates(String? sosId) {
    if (sosId == null || sosId.isEmpty) return;
    _liveLocationTimer?.cancel();
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (!_isTriggered || !mounted) {
        _liveLocationTimer?.cancel();
        return;
      }
      final pos = await _locationService.getCurrentLocation();
      if (pos != null) {
        setState(() => _currentPosition = pos);
        await _apiService.updateSOSLocation(
          sosId: sosId,
          lat: pos.latitude,
          lng: pos.longitude,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isTriggered) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            children: [
              _buildStatusBar(),
              const Spacer(),
              _isActivating ? _buildCountdownDisplay() : _buildMainSOSButton(),
              const Spacer(),
              _buildEmergencyContacts(),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    return Column(
      children: [
        Text(
          _isActivating ? "ACTIVATING SOS" : "Safe Her SOS",
          style: TextStyle(
            color: _isActivating ? const Color(0xFFE71C23) : const Color(0xFF1F1F1F),
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentPosition != null ? const Color(0xFF00ADB5) : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _currentPosition != null ? "Precision Location Active" : "Searching for GPS signal...",
              style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMainSOSButton() {
    return Column(
      children: [
        const Text(
          "SWIPE FOR EMERGENCY",
          style: TextStyle(
            color: Color(0xFFE71C23),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 300,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Stack(
            children: [
              const Center(
                child: Text(
                  "Slide to Call Help",
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Dismissible(
                key: const Key("sos_swipe"),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (direction) async {
                  _activateSOS(); // Direct activation for swipe
                  return false;
                },
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE71C23),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFFFF9494),
                          blurRadius: 12,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownDisplay() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 220, height: 220,
              child: CircularProgressIndicator(
                value: _countdown / 5,
                strokeWidth: 10,
                color: const Color(0xFFE71C23),
                backgroundColor: const Color(0xFFF2F2F7),
              ),
            ),
            Text("$_countdown", style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 84, fontWeight: FontWeight.w900)),
          ],
        ),
        const SizedBox(height: 48),
        TextButton.icon(
          onPressed: _cancelSOS,
          icon: const Icon(Icons.close_rounded, color: Color(0xFFE71C23)),
          label: const Text("CANCEL DISPATCH", style: TextStyle(color: Color(0xFFE71C23), fontWeight: FontWeight.w900, letterSpacing: 1)),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            side: const BorderSide(color: Color(0xFFE71C23), width: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      ],
    );
  }

  Widget _buildEmergencyContacts() {
    return Column(
      children: [
        const Text("EMERGENCY DISPATCH", style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1)),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _emergencyButton("100", "Police"),
            _emergencyButton("108", "Med"),
            _emergencyButton("112", "SOS"),
            _emergencyButton("1091", "Women"),
          ],
        ),
      ],
    );
  }

  Widget _emergencyButton(String num, String label) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse('tel:$num');
        try {
          await launchUrl(uri);
        } catch (e) {
          debugPrint('Could not launch phone call to $num: $e');
        }
      },
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F2F7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(child: Text(num, style: const TextStyle(color: Color(0xFF1F1F1F), fontWeight: FontWeight.w900, fontSize: 15))),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(color: Color(0xFF00ADB5), shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, color: Colors.white, size: 64),
              ),
              const SizedBox(height: 32),
              const Text("Alert Sent!", style: TextStyle(color: Color(0xFF1F1F1F), fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 12),
              _buildTrackingCard(),
              const SizedBox(height: 24),
              if (_sosResponse?['all_police_stations'] != null) ...[
                const Text(
                  "UNITS DISPATCHED",
                  style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: (_sosResponse!['all_police_stations'] as List).length,
                    separatorBuilder: (ctx, _) => const SizedBox(width: 12),
                    itemBuilder: (ctx, i) {
                      final station = _sosResponse!['all_police_stations'][i];
                      return Container(
                        width: 160,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(16),
                          border: i == 0 ? Border.all(color: const Color(0xFFE71C23), width: 1.5) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_police_rounded, color: i == 0 ? const Color(0xFFE71C23) : const Color(0xFF5D3891), size: 16),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    station['name'],
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            Text(
                              "${station['distance_km']}km • ${station['eta_minutes']}min",
                              style: TextStyle(
                                color: i == 0 ? const Color(0xFFE71C23) : const Color(0xFF666666),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ] else if (_sosResponse?['police_station'] != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.local_police_rounded, color: Color(0xFF5D3891), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _sosResponse!['police_station']['name'],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Help arriving in approx. ${_sosResponse!['eta_minutes']} minutes",
                        style: const TextStyle(color: Color(0xFFE71C23), fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                _sosResponse?['police_station'] != null 
                  ? "Your location has been broadcast to ${_sosResponse!['police_station']['name']}. Help is on the way."
                  : "Your location and SOS signal have been broadcast to local emergency services and your contacts.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  _liveLocationTimer?.cancel();
                  setState(() => _isTriggered = false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D3891),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text("I AM SAFE NOW", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF5D3891).withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: Color(0xFF5D3891), shape: BoxShape.circle),
                child: const Icon(Icons.local_police_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Help is on the way", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1F1F1F))),
                    Text("Top 5 police units notified", style: TextStyle(color: const Color(0xFF5D3891), fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("ETA", style: TextStyle(color: Color(0xFF8E8E93), fontSize: 10, fontWeight: FontWeight.w800)),
                  Text(_formatTime(_etaSeconds), style: const TextStyle(color: Color(0xFFE71C23), fontWeight: FontWeight.w900, fontSize: 18)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const LinearProgressIndicator(
            value: 0.3, // Static for demo, could be dynamic
            backgroundColor: Colors.white,
            color: Color(0xFF00ADB5),
            minHeight: 6,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Dispatched", style: TextStyle(color: Color(0xFF00ADB5), fontWeight: FontWeight.w800, fontSize: 11)),
              Text("Stay in a public place", style: TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w600, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
