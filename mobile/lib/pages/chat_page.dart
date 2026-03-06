import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();

  Position? _pos;
  String? _conversationId;
  String? _selectedImageBase64;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingSeconds = 0;
  String? _currentRecordingPath;
  String _userId = '';

  // Waveform animation data
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _waveController;
  final List<double> _waveformBars = List.generate(24, (_) => 0.3);

  final List<Map<String, dynamic>> _messages = [
    {
      'role': 'assistant',
      'text':
          "Hello! 🙏 I'm SafeHer AI, your Tamil Nadu safety companion.\n\nI can help you with:\n• 🚨 Emergency guidance\n• 📍 Nearest police & hospitals\n• 🛡️ Safety tips for any place\n• 🌤️ Weather info\n• 📸 Analyze photos for safety\n• 🎤 Voice messages supported\n\nHow can I help keep you safe today?"
    }
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _getLocation();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (user != null && mounted) {
      setState(() => _userId = user['id'] ?? '');
    }
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..addListener(() {
        if (_isRecording && mounted) {
          setState(() {
            // Shift bars left and add a new random bar
            _waveformBars.removeAt(0);
            _waveformBars.add(0.2 + Random().nextDouble() * 0.8);
          });
        }
      });
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _getLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (mounted) setState(() => _pos = pos);
  }

  void _sendMessage({String? voiceBase64}) async {
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImage = _selectedImageBase64 != null;
    final hasVoice = voiceBase64 != null;

    if (!hasText && !hasImage && !hasVoice) return;
    if (_isLoading) return;

    final userMsg = _controller.text.trim();
    final image = _selectedImageBase64;

    setState(() {
      String displayText;
      if (hasVoice) {
        displayText = "🎤 Voice message (${_recordingSeconds}s)${userMsg.isNotEmpty ? '\n$userMsg' : ''}";
      } else if (hasImage) {
        displayText = "📸 Photo${userMsg.isNotEmpty ? ': $userMsg' : ' attached'}";
      } else {
        displayText = userMsg;
      }

      _messages.add({
        'role': 'user',
        'text': displayText,
        'hasImage': hasImage,
        'image': image,
        'hasVoice': hasVoice,
      });
      _isLoading = true;
      _selectedImageBase64 = null;
    });
    _controller.clear();
    _scrollToBottom();

    final response = await _apiService.sendMessage(
      message: userMsg,
      conversationId: _conversationId,
      location: _pos != null
          ? {'lat': _pos!.latitude, 'lng': _pos!.longitude}
          : null,
      imageBase64: image,
      voiceBase64: voiceBase64,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _conversationId = response['conversation_id'];
        _messages.add({
          'role': 'assistant',
          'text': response['success'] == true
              ? (response['response'] ??
                  "I'm having trouble responding. Call 112 for emergencies.")
              : (response['error']?.toString().contains("429") == true
                  ? "I'm experiencing high traffic. For your safety: stay in well-lit areas. If in danger, call 100 or 112 immediately."
                  : "Connection issue. For emergencies: Call 100 (Police) or 112."),
        });
      });
      _scrollToBottom();
    }
  }

  // ─── Camera / Gallery Bottom Sheet ─────────────────────────────

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Add a photo",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F1F1F),
              ),
            ),
            const SizedBox(height: 20),
            // Camera option
            _buildSourceOption(
              icon: Icons.camera_alt_rounded,
              color: const Color(0xFF5D3891),
              label: "Camera",
              subtitle: "Take a new photo",
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            const SizedBox(height: 12),
            // Gallery option
            _buildSourceOption(
              icon: Icons.photo_library_rounded,
              color: const Color(0xFF00ADB5),
              label: "Gallery",
              subtitle: "Choose from your photos",
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceOption({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: color)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF8E8E93))),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final camStatus = await Permission.camera.status;
        if (!camStatus.isGranted) {
          final result = await Permission.camera.request();
          if (!result.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Camera permission needed."),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: openAppSettings,
                  ),
                ),
              );
            }
            return;
          }
        }
      }

      final XFile? image =
          await _picker.pickImage(source: source, imageQuality: 70);
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) {
          setState(() {
            _selectedImageBase64 = base64Encode(bytes);
          });
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(source == ImageSource.camera
                  ? "📸 Photo captured! Tap ↑ to send."
                  : "🖼️ Photo selected! Tap ↑ to send.")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // ─── Microphone Recording ──────────────────────────────────────

  Future<void> _startRecording() async {
    // Request mic permission
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Microphone permission needed."),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: openAppSettings,
              ),
            ),
          );
        }
        return;
      }
    }

    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/chat_record_${DateTime.now().millisecondsSinceEpoch}.m4a';
      const config = RecordConfig();
      await _audioRecorder.start(config, path: path);

      _currentRecordingPath = path;
      _recordingSeconds = 0;
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordingSeconds++);
      });
      _pulseController.repeat(reverse: true);
      _waveController.repeat();

      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopAndSendRecording() async {
    final path = await _audioRecorder.stop();
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();

    final seconds = _recordingSeconds;
    setState(() => _isRecording = false);

    if (path != null) {
      final bytes = await File(path).readAsBytes();
      final voiceBase64 = base64Encode(bytes);
      // Auto-send the voice message (duration shown: ${seconds}s)
      _sendMessage(voiceBase64: voiceBase64);
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    _recordingTimer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
    _waveController.stop();
    _waveController.reset();
    _recordingSeconds = 0;

    // Delete the recorded file
    if (_currentRecordingPath != null) {
      try {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    setState(() => _isRecording = false);
  }

  String _formatDuration(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(1, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF5D3891).withOpacity(0.1), width: 2),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFFF5F5F7),
                radius: 18,
                child: Icon(Icons.auto_awesome_rounded,
                    color: Color(0xFF5D3891), size: 18),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("SafeHer AI",
                    style: TextStyle(
                        color: Color(0xFF1F1F1F),
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        letterSpacing: -0.5)),
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: Color(0xFF00ADB5),
                            shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text("Always Active",
                        style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Selected media preview (image only since voice auto-sends)
          if (_selectedImageBase64 != null) _buildMediaPreview(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildTypingIndicator();
                }
                return _buildMessage(_messages[index]);
              },
            ),
          ),
          // Show recording overlay OR normal input bar
          _isRecording ? _buildRecordingOverlay() : _buildInput(),
        ],
      ),
    );
  }

  // ─── Recording Overlay (ChatGPT-style) ─────────────────────────

  Widget _buildRecordingOverlay() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Waveform visualization
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_waveformBars.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  width: 3,
                  height: 8 + (_waveformBars[i] * 28),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE71C23)
                        .withOpacity(0.4 + _waveformBars[i] * 0.6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Timer + controls row
          Row(
            children: [
              // Cancel button
              GestureDetector(
                onTap: _cancelRecording,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFF8E8E93), size: 22),
                ),
              ),
              // Timer in center
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) => Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE71C23),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE71C23)
                                      .withOpacity(0.4),
                                  blurRadius: _pulseAnimation.value * 6,
                                  spreadRadius: _pulseAnimation.value * 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          _formatDuration(_recordingSeconds),
                          style: const TextStyle(
                            color: Color(0xFFE71C23),
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Recording...",
                      style: TextStyle(
                        color: Color(0xFF8E8E93),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Stop & Send button
              GestureDetector(
                onTap: _stopAndSendRecording,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5D3891),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.send_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF5D3891).withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5D3891).withOpacity(0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_rounded,
              color: Color(0xFF5D3891), size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              "📸 Photo ready to send",
              style: TextStyle(
                  color: Color(0xFF5D3891),
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedImageBase64 = null;
            }),
            child: const Icon(Icons.close_rounded,
                color: Color(0xFF8E8E93), size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isUser = msg['role'] == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.80),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isUser
              ? const Color(0xFF5D3891)
              : const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image preview — decode base64 and show actual photo ──
            if (msg['hasImage'] == true && msg['image'] != null) ...[
              GestureDetector(
                onTap: () => _showFullImage(msg['image'] as String),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(msg['image'] as String),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                          child: Icon(Icons.broken_image_rounded,
                              color: Colors.white70, size: 36)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ] else if (msg['hasImage'] == true) ...[
              Container(
                height: 120,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Icon(Icons.image_rounded,
                        color: Colors.white70, size: 36)),
              ),
            ],
            // ── Voice message badge ──
            if (msg['hasVoice'] == true) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_none_rounded, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text("Voice message",
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
            // ── Message text: plain text for both user and AI ──
            if (isUser)
              Text(
                msg['text'] as String,
                style: const TextStyle(
                  color: Colors.white,
                  height: 1.4,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              SelectableText(
                msg['text'] as String,
                style: const TextStyle(
                  color: Color(0xFF1F1F1F),
                  fontSize: 14.5,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Show full-screen image preview when user taps on a photo
  void _showFullImage(String base64Image) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: InteractiveViewer(
                child: Image.memory(
                  base64Decode(base64Image),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F2F7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF5D3891)),
            ),
            SizedBox(width: 12),
            Text("AI is analyzing...",
                style: TextStyle(
                    color: Color(0xFF8E8E93),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black12, blurRadius: 4, offset: Offset(0, -1))
        ],
      ),
      child: Row(
        children: [
          // Camera button → opens bottom sheet with Camera/Gallery options
          GestureDetector(
            onTap: _showImageSourcePicker,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _selectedImageBase64 != null
                    ? const Color(0xFF00ADB5).withOpacity(0.1)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.camera_alt_rounded,
                color: _selectedImageBase64 != null
                    ? const Color(0xFF00ADB5)
                    : const Color(0xFF8E8E93),
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mic button → starts recording overlay
          GestureDetector(
            onTap: _startRecording,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Color(0xFF8E8E93),
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                    color: Color(0xFF1F1F1F), fontSize: 15),
                decoration: const InputDecoration(
                  hintText: "Type, record or take a photo...",
                  hintStyle:
                      TextStyle(color: Color(0xFF8E8E93), fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _sendMessage(),
                maxLines: null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFF5D3891),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_upward_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
