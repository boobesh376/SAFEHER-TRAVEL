import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class ResourcesPage extends StatefulWidget {
  const ResourcesPage({super.key});

  @override
  State<ResourcesPage> createState() => _ResourcesPageState();
}

class _ResourcesPageState extends State<ResourcesPage> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();

  List<dynamic> _resources = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  Position? _currentPos;
  Position? _lastLoadedPos;
  String _selectedCategory = 'police';
  Timer? _refreshTimer;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _loadResources();
    _startLiveTracking();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLiveTracking() {
    // Location stream - refresh when user moves >500m
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 500, // Only fire when user moves 500m
    );

    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position pos) {
      _currentPos = pos;
      if (mounted) {
        _silentRefresh();
      }
    });

    // Also poll every 30 seconds as a safety net
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && !_isLoading) {
        _silentRefresh();
      }
    });
  }

  Future<void> _silentRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      final pos = _currentPos ?? await _locationService.getCurrentLocation();
      if (pos == null) return;

      final response = _selectedCategory == 'police'
          ? await _apiService.getNearbyPolice(pos.latitude, pos.longitude)
          : await _apiService.getNearbyHospitals(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _resources =
              response['stations'] ?? response['hospitals'] ?? [];
          _lastLoadedPos = pos;
          _isRefreshing = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadResources() async {
    setState(() => _isLoading = true);
    try {
      final pos = await _locationService.getCurrentLocation();
      if (pos == null) throw Exception("Could not get location");
      _currentPos = pos;
      _lastLoadedPos = pos;

      final response = _selectedCategory == 'police'
          ? await _apiService.getNearbyPolice(pos.latitude, pos.longitude)
          : await _apiService.getNearbyHospitals(pos.latitude, pos.longitude);

      if (mounted) {
        setState(() {
          _resources =
              response['stations'] ?? response['hospitals'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDistance(dynamic dist) {
    if (dist == null) return '';
    final d = dist is num ? dist.toDouble() : double.tryParse(dist.toString()) ?? 0.0;
    if (d < 1.0) return '${(d * 1000).round()} m away';
    return '${d.toStringAsFixed(1)} km away';
  }

  Future<void> _callNumber(String phone) async {
    final cleanPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri.parse('tel:$cleanPhone');
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Call Emergency Services",
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("Call $phone now?",
            style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF8E8E93))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5D3891),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Call Now",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Emergency Resources",
              style: TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontWeight: FontWeight.w900,
                  fontSize: 20),
            ),
            if (_isRefreshing)
              const Text("Updating location...",
                  style: TextStyle(
                      color: Color(0xFF00ADB5),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF00ADB5)),
                ),
              ),
            ),
          IconButton(
            onPressed: _loadResources,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF5D3891)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Live tracking banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF00ADB5).withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded,
                    color: Color(0xFF00ADB5), size: 14),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text("Live tracking active • Updates every 30s or when you move 500m",
                      style: TextStyle(
                          color: Color(0xFF00ADB5),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          _buildCategoryToggle(),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFF5D3891)))
                : _resources.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _resources.length,
                        itemBuilder: (ctx, i) =>
                            _buildResourceCard(_resources[i]),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          _toggleItem("Police", 'police', Icons.local_police_rounded),
          const SizedBox(width: 12),
          _toggleItem("Hospitals", 'hospital', Icons.medical_services_rounded),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, String val, IconData icon) {
    final isSel = _selectedCategory == val;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedCategory = val);
          _loadResources();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSel ? const Color(0xFF5D3891) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: isSel ? Colors.white : const Color(0xFF5D3891),
                  size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSel ? Colors.white : const Color(0xFF1F1F1F),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedCategory == 'police'
                ? Icons.local_police_outlined
                : Icons.local_hospital_outlined,
            size: 64,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            "No ${_selectedCategory == 'police' ? 'police stations' : 'hospitals'} found nearby",
            style: TextStyle(
                color: Colors.grey[600], fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadResources,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Try Again"),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(dynamic station) {
    final isPolice = _selectedCategory == 'police';
    final phone = station['phone']?.toString() ??
        station['emergency_phone']?.toString() ??
        (isPolice ? '100' : '108');
    final distance = _formatDistance(station['distance_km']);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withOpacity(0.03)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isPolice
                          ? const Color(0xFF5D3891)
                          : const Color(0xFFE71C23))
                      .withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPolice
                      ? Icons.local_police_rounded
                      : Icons.local_hospital_rounded,
                  color: isPolice
                      ? const Color(0xFF5D3891)
                      : const Color(0xFFE71C23),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      station['name'] ??
                          (isPolice ? 'Police Station' : 'Hospital'),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: Color(0xFF1F1F1F)),
                    ),
                    if (distance.isNotEmpty)
                      Text(
                        distance,
                        style: const TextStyle(
                            color: Color(0xFF00ADB5),
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                  ],
                ),
              ),
              // Source badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ADB5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  station['source'] == 'OpenStreetMap' ? "🗺 Live" : "📍 DB",
                  style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF00ADB5),
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),

          if ((station['address'] ?? station['vicinity']) != null)
            Row(
              children: [
                const Icon(Icons.location_on_rounded,
                    size: 14, color: Color(0xFF8E8E93)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station['address'] ?? station['vicinity'] ?? '',
                    style: const TextStyle(
                        color: Color(0xFF8E8E93), fontSize: 12),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.phone_rounded,
                  size: 14, color: Color(0xFF00ADB5)),
              const SizedBox(width: 6),
              Text(
                phone,
                style: const TextStyle(
                    color: Color(0xFF00ADB5),
                    fontSize: 13,
                    fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _actionButton(
                  icon: Icons.phone_rounded,
                  label: "Call Now",
                  color: const Color(0xFF5D3891),
                  onTap: () => _callNumber(phone),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _actionButton(
                  icon: Icons.directions_rounded,
                  label: "Navigate",
                  color: const Color(0xFF00ADB5),
                  onTap: () async {
                    final lat = station['lat'] ?? station['latitude'];
                    final lng = station['lng'] ?? station['longitude'];
                    final name =
                        Uri.encodeComponent(station['name'] ?? 'Destination');
                    final uri = Uri.parse(
                        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
