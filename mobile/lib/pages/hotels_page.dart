import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class HotelsPage extends StatefulWidget {
  const HotelsPage({super.key});

  @override
  State<HotelsPage> createState() => _HotelsPageState();
}

class _HotelsPageState extends State<HotelsPage> {
  final ApiService _apiService = ApiService();
  final LocationService _locationService = LocationService();
  List<dynamic> _hotels = [];
  bool _isLoading = true;
  String? _error;
  Position? _pos;

  @override
  void initState() {
    super.initState();
    _fetchHotels();
  }

  Future<void> _fetchHotels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final pos = await _locationService.getCurrentLocation();
      setState(() => _pos = pos);
      if (pos != null) {
        final res =
            await _apiService.getNearbyHotels(pos.latitude, pos.longitude);
        if (mounted) {
          setState(() {
            _hotels = res['accommodations'] ?? res['hotels'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = "Location permission needed.";
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Could not fetch hotels. Make sure backend is running.";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 130,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(color: Colors.white),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text("Elite Stays",
                            style: TextStyle(
                                color: Color(0xFF1F1F1F),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5)),
                        const SizedBox(height: 4),
                        const Text(
                            "Safety-vetted hotels • Powered by Google Reviews",
                            style: TextStyle(
                                color: Color(0xFF8E8E93),
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: IconButton(
                  onPressed: _fetchHotels,
                  icon: const Icon(Icons.refresh_rounded,
                      color: Color(0xFF5D3891)),
                ),
              ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child:
                  Center(child: CircularProgressIndicator(color: Color(0xFF5D3891))),
            )
          else if (_error != null)
            SliverFillRemaining(child: _buildError())
          else if (_hotels.isEmpty)
            SliverFillRemaining(child: _buildEmpty())
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, index) => _buildHotelCard(_hotels[index]),
                  childCount: _hotels.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHotelCard(dynamic hotel) {
    final rating = hotel['rating'] ?? hotel['safety_rating'] ?? 0.0;
    final ratingNum = rating is num ? rating.toDouble() : 0.0;
    final distance = hotel['distance_km'];
    final priceLevel = hotel['price_level'] ?? 2;
    final priceSigns =
        '₹' * (priceLevel is int ? priceLevel.clamp(1, 4) : 2);
    final amenities = (hotel['amenities'] as List?)?.cast<String>() ?? [];
    final reviews = (hotel['reviews'] as List?) ?? [];
    final phone = hotel['phone']?.toString();
    final website = hotel['website']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF2F2F7)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel['name'] ?? 'Hotel',
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: -0.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (ratingNum > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFF9A826).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 15, color: Color(0xFFF9A826)),
                            const SizedBox(width: 3),
                            Text(ratingNum.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFFF9A826),
                                    fontSize: 13)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if ((hotel['address'] ?? hotel['vicinity']) != null)
                  Row(
                    children: [
                      const Icon(Icons.place_rounded,
                          size: 14, color: Color(0xFF8E8E93)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotel['address'] ?? hotel['vicinity'] ?? '',
                          style: const TextStyle(
                              color: Color(0xFF8E8E93),
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                if (distance != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.directions_walk_rounded,
                            size: 14, color: Color(0xFF00ADB5)),
                        const SizedBox(width: 4),
                        Text(
                          "${distance is num ? distance.toStringAsFixed(1) : distance} km away",
                          style: const TextStyle(
                              color: Color(0xFF00ADB5),
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Text(priceSigns,
                            style: const TextStyle(
                                color: Color(0xFF1F1F1F),
                                fontWeight: FontWeight.w900,
                                fontSize: 14)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ─── Amenities ───
          if (amenities.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: amenities
                    .take(4)
                    .map((a) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF5D3891).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(a,
                              style: const TextStyle(
                                  color: Color(0xFF5D3891),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ))
                    .toList(),
              ),
            ),

          // ─── Google Reviews Sideways Carousel ───
          if (reviews.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 0, 8),
              child: Row(
                children: [
                  Icon(Icons.rate_review_rounded,
                      size: 14, color: Color(0xFF8E8E93)),
                  SizedBox(width: 6),
                  Text("Google Reviews",
                      style: TextStyle(
                          color: Color(0xFF8E8E93),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            SizedBox(
              height: 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.only(left: 20, right: 8, bottom: 4),
                itemCount: reviews.length,
                itemBuilder: (ctx, i) =>
                    _buildReviewCard(reviews[i]),
              ),
            ),
          ] else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.star_border_rounded,
                        size: 16, color: Color(0xFF8E8E93)),
                    SizedBox(width: 8),
                    Text("No reviews available yet",
                        style: TextStyle(
                            color: Color(0xFF8E8E93),
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],

          // ─── Safety Badge + Actions ───
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color:
                            const Color(0xFF00ADB5).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.verified_user_rounded,
                              size: 14, color: Color(0xFF00ADB5)),
                          SizedBox(width: 6),
                          Text("Safety Vetted",
                              style: TextStyle(
                                  color: Color(0xFF00ADB5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3)),
                        ],
                      ),
                    ),
                    const Spacer(),
                    if (hotel['is_open'] == true)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text("Open Now",
                            style: TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w900)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (phone != null)
                      Expanded(
                        child: _actionBtn(
                          icon: Icons.phone_rounded,
                          label: "Call Hotel",
                          color: const Color(0xFF5D3891),
                          onTap: () async {
                            final uri = Uri.parse('tel:$phone');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          },
                        ),
                      ),
                    if (phone != null) const SizedBox(width: 10),
                    Expanded(
                      child: _actionBtn(
                        icon: Icons.open_in_new_rounded,
                        label: "View on Google",
                        color: const Color(0xFF00ADB5),
                        onTap: () async {
                          final lat = hotel['latitude'];
                          final lng = hotel['longitude'];
                          final name = Uri.encodeComponent(
                              hotel['name'] ?? 'Hotel');
                          final uri = Uri.parse(
                              'https://www.google.com/maps/search/?api=1&query=$name&query_place_id=${hotel['id'] ?? ''}');
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
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic review) {
    final author = review['author_name'] ?? 'Guest';
    final rating = (review['rating'] ?? 4) as num;
    String text = review['text'] ?? '';
    if (text.length > 130) text = '${text.substring(0, 127)}...';
    final initials = author.isNotEmpty ? author[0].toUpperCase() : 'G';

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor:
                    const Color(0xFF5D3891).withOpacity(0.1),
                child: Text(initials,
                    style: const TextStyle(
                        color: Color(0xFF5D3891),
                        fontWeight: FontWeight.w900,
                        fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(author,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: Color(0xFF1F1F1F)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    Icons.star_rounded,
                    size: 10,
                    color: i < rating
                        ? const Color(0xFFF9A826)
                        : Colors.grey[300],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Expanded(
            child: Text(
              text.isEmpty ? 'Great experience!' : text,
              style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 11,
                  height: 1.4),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
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
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.hotel_outlined, size: 60, color: Color(0xFFF2F2F7)),
            const SizedBox(height: 24),
            const Text('No Hotels Found',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF1F1F1F))),
            const SizedBox(height: 8),
            const Text(
                'Add GOOGLE_PLACES_API_KEY to the backend .env for real-time Google results.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF8E8E93), fontSize: 13)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchHotels,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5D3891),
                  foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: Color(0xFFE71C23)),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: _fetchHotels,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
