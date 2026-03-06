import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'resources_page.dart';

class DashboardPage extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardPage({super.key, required this.onNavigate});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _user;
  bool _isLoading = true;
  int _nearbyPolice = 0;
  int _nearbyHospitals = 0;
  Position? _currentPos;
  StreamSubscription<Position>? _positionStream;
  final ApiService _api = ApiService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _loadData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _positionStream?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthService.getUser();
      setState(() => _user = user);
      
      // Explicitly check and request permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission != LocationPermission.denied && permission != LocationPermission.deniedForever) {
        // Start live tracking
        _startLocationStreaming();
      } else {
        if (mounted) {
          setState(() { _isLoading = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required for full protection features."))
          );
        }
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _startLocationStreaming() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium, // Use medium for better performance and battery
      distanceFilter: 200, // Update every 200 meters to reduce API hammering
    );

    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) {
        _updateNearbyResources(position);
      },
    );
  }

  Future<void> _updateNearbyResources(Position pos) async {
    try {
      final results = await Future.wait([
        _api.getNearbyPolice(pos.latitude, pos.longitude),
        _api.getNearbyHospitals(pos.latitude, pos.longitude),
      ]);

      if (mounted) {
        setState(() {
          _currentPos = pos;
          _nearbyPolice = results[0]['count'] ?? 0;
          _nearbyHospitals = results[1]['count'] ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error updating resources: $e");
    }
  }

  void _triggerEmergencySOS() {
    HapticFeedback.heavyImpact();
    widget.onNavigate(2); // Navigate to SOS tab
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF5D3891))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Subtle background decoration
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5D3891).withOpacity(0.03),
              ),
            ),
          ),
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 10),
                      _buildSafetyIllustration(),
                      const SizedBox(height: 40),
                      _buildSOSCenter(),
                      const SizedBox(height: 50),
                      const Text(
                        'Nearby Resources',
                        style: TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildSafetyMetrics(),
                      const SizedBox(height: 40),
                      const Text(
                        'Safety Features',
                        style: TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildVisualActionGrid(),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF5D3891).withOpacity(0.2), width: 2),
              ),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFF5F5F7),
                child: Text(
                  _user?['name']?.substring(0, 1).toUpperCase() ?? 'S',
                  style: const TextStyle(color: Color(0xFF5D3891), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: TextStyle(color: const Color(0xFF8E8E93), fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_user?['name'] ?? 'Traveler'}',
                  style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                ),
              ],
            ),
            const Spacer(),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF5D3891), size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyIllustration() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5D3891), Color(0xFF432C7A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5D3891).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, bottom: -20,
            child: Opacity(
              opacity: 0.2,
              child: Icon(Icons.shield_rounded, size: 150, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Always Protected',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'SafeHer Shield is active and\nmonitoring your safety status.',
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSCenter() {
    return Column(
      children: [
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
                  "Swipe for Emergency",
                  style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Dismissible(
                key: const Key("dash_sos_swipe"),
                direction: DismissDirection.startToEnd,
                confirmDismiss: (direction) async {
                  _triggerEmergencySOS();
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

  Widget _buildSafetyMetrics() {
    return Row(
      children: [
        _metricBox('Police Stations', _nearbyPolice.toString(), Icons.local_police_rounded, const Color(0xFF2D31FA)),
        const SizedBox(width: 16),
        _metricBox('Hospitals', _nearbyHospitals.toString(), Icons.emergency_rounded, const Color(0xFFE71C23)),
      ],
    );
  }

  Widget _metricBox(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF2F2F7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 16),
            Text(value, style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 28, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(title, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualActionGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.1,
      children: [
        _featureCard('AI Chat', 'Safe Companion', 'assets/images/ai_chat.png', const Color(0xFF5D3891), 1),
        _featureCard('Community', 'Public Experience', 'assets/images/community_art.png', const Color(0xFFF9A826), 6),
        _featureCard('Nearby Help', 'Police & Hospitals', 'assets/images/emergency_art.png', const Color(0xFF2D31FA), -1),
        _featureCard('Safety Map', 'Live Navigation', 'assets/images/map_art_new.png', const Color(0xFF00ADB5), 3),
      ],
    );
  }

  Widget _featureCard(String title, String sub, String imagePath, Color color, int index) {
    return GestureDetector(
      onTap: () {
        if (index == -1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ResourcesPage()));
        } else {
          widget.onNavigate(index);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFF2F2F7)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Image Background
              Positioned(
                top: 0, left: 0, right: 0, bottom: 50,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              // Bottom Content
              Positioned(
                bottom: 0, left: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.white.withOpacity(0), Colors.white],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0, 0.4],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(color: Color(0xFF1F1F1F), fontSize: 15, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(width: 4, height: 4, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(sub, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
