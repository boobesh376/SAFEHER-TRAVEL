import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionsPage extends StatefulWidget {
  final VoidCallback onComplete;
  const PermissionsPage({super.key, required this.onComplete});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

class _PermissionsPageState extends State<PermissionsPage> {
  bool _locationGranted = false;
  bool _micGranted = false;
  bool _cameraGranted = false;
  bool _notificationGranted = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatuses();
  }

  Future<void> _checkCurrentStatuses() async {
    // Check location via Geolocator (works on web + mobile)
    final locPerm = await Geolocator.checkPermission();
    final locGranted = locPerm == LocationPermission.always ||
        locPerm == LocationPermission.whileInUse;

    bool micOk = false;
    bool camOk = false;
    bool notifOk = false;

    if (!kIsWeb) {
      // permission_handler only works on mobile, not web
      micOk = (await Permission.microphone.status).isGranted;
      camOk = (await Permission.camera.status).isGranted;
      notifOk = (await Permission.notification.status).isGranted;
    } else {
      // On web, mic/camera are requested when actually used (browser handles it)
      // Just mark as granted so user can proceed
      micOk = true;
      camOk = true;
      notifOk = true;
    }

    if (mounted) {
      setState(() {
        _locationGranted = locGranted;
        _micGranted = micOk;
        _cameraGranted = camOk;
        _notificationGranted = notifOk;
      });
    }
  }

  Future<void> _requestLocation() async {
    setState(() => _loading = true);
    try {
      // Use Geolocator for location — works on both web and mobile
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Please enable Location Services on your device")),
          );
        }
        setState(() => _loading = false);
        return;
      }

      final permission = await Geolocator.requestPermission();
      final granted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;

      if (mounted) {
        setState(() {
          _locationGranted = granted;
          _loading = false;
        });
        if (!granted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied. Tap again or enable in Settings.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Location error: $e")),
        );
      }
    }
  }

  Future<void> _requestMic() async {
    if (kIsWeb) {
      setState(() => _micGranted = true);
      return;
    }
    final status = await Permission.microphone.request();
    if (mounted) setState(() => _micGranted = status.isGranted);
  }

  Future<void> _requestCamera() async {
    if (kIsWeb) {
      setState(() => _cameraGranted = true);
      return;
    }
    final status = await Permission.camera.request();
    if (mounted) setState(() => _cameraGranted = status.isGranted);
  }

  Future<void> _requestNotification() async {
    if (kIsWeb) {
      setState(() => _notificationGranted = true);
      return;
    }
    final status = await Permission.notification.request();
    if (mounted) setState(() => _notificationGranted = status.isGranted);
  }

  Future<void> _grantAll() async {
    setState(() => _loading = true);
    await _requestLocation();
    if (!kIsWeb) {
      await _requestMic();
      await _requestCamera();
      await _requestNotification();
    } else {
      setState(() {
        _micGranted = true;
        _cameraGranted = true;
        _notificationGranted = true;
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  MediaQuery.of(context).padding.bottom - 48,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D3891).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      size: 64, color: Color(0xFF5D3891)),
                ),
                const SizedBox(height: 24),
                const Text(
                  "Trust & Safety",
                  style: TextStyle(
                      color: Color(0xFF1F1F1F),
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  "SafeHer needs these permissions once to keep you safe. You won't be asked again.",
                  style: TextStyle(
                      color: Color(0xFF8E8E93),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                _permissionTile(
                  icon: Icons.location_on_rounded,
                  title: "Location",
                  sub: "Find nearby police, hospitals & safe routes",
                  granted: _locationGranted,
                  onTap: _requestLocation,
                ),
                const SizedBox(height: 12),
                _permissionTile(
                  icon: Icons.mic_rounded,
                  title: "Microphone",
                  sub: kIsWeb
                      ? "Browser will ask when you use voice chat"
                      : "Send voice messages to SafeHer AI chatbot",
                  granted: _micGranted,
                  onTap: _requestMic,
                ),
                const SizedBox(height: 12),
                _permissionTile(
                  icon: Icons.camera_alt_rounded,
                  title: "Camera",
                  sub: kIsWeb
                      ? "Browser will ask when you take a photo"
                      : "Share photos with AI for threat analysis",
                  granted: _cameraGranted,
                  onTap: _requestCamera,
                ),
                const SizedBox(height: 12),
                _permissionTile(
                  icon: Icons.notifications_active_rounded,
                  title: "Notifications",
                  sub: "Emergency alerts and safety reminders",
                  granted: _notificationGranted,
                  onTap: _requestNotification,
                ),

                const SizedBox(height: 32),

                // Grant All button
                if (!_locationGranted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: OutlinedButton(
                      onPressed: _loading ? null : _grantAll,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF5D3891)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        _loading ? "Requesting..." : "Grant All Permissions",
                        style: const TextStyle(
                            color: Color(0xFF5D3891),
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),

                ElevatedButton(
                  onPressed: _locationGranted ? widget.onComplete : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5D3891),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: Text(
                    _locationGranted
                        ? "Continue to App →"
                        : "Grant Location to Continue",
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                if (!_locationGranted)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      "📍 Location permission is required to use SafeHer.",
                      style: TextStyle(
                          color: Color(0xFFE71C23),
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _permissionTile({
    required IconData icon,
    required String title,
    required String sub,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: granted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: granted
              ? const Color(0xFF00ADB5).withOpacity(0.06)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: granted
                ? const Color(0xFF00ADB5).withOpacity(0.3)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: granted
                    ? const Color(0xFF00ADB5)
                    : const Color(0xFF5D3891).withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon,
                  color: granted ? Colors.white : const Color(0xFF5D3891),
                  size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF1F1F1F))),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: const TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 11,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: granted ? const Color(0xFF00ADB5) : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                granted ? Icons.check_rounded : Icons.add_rounded,
                color: granted ? Colors.white : const Color(0xFF8E8E93),
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
