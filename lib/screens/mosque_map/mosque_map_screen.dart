import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:async';
import '../../core/theme/app_colors.dart';

class MosqueMapScreen extends StatefulWidget {
  const MosqueMapScreen({super.key});

  @override
  State<MosqueMapScreen> createState() => _MosqueMapScreenState();
}

class _MosqueMapScreenState extends State<MosqueMapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  // State
  LatLng? _currentLocation;
  List<Map<String, dynamic>> _mosques = [];
  List<Map<String, dynamic>> _filteredMosques = []; // Added filtered list
  String? _selectedMosqueId;

  // Animation for pulsing user location
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeLocation();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Default to Monas Jakarta if GPS disabled
      _setDefaultLocation();
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _setDefaultLocation();
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _setDefaultLocation();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _fetchNearbyMosques();
    } catch (e) {
      _setDefaultLocation();
    }
  }

  void _setDefaultLocation() {
    setState(() {
      _currentLocation = const LatLng(-6.175392, 106.827153); // Monas
    });
    _fetchNearbyMosques();
  }

  Future<void> _fetchNearbyMosques() async {
    if (_currentLocation == null) return;

    // Overpass API Query: Mosque within 5km
    final query =
        """
      [out:json];
      (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:5000, ${_currentLocation!.latitude}, ${_currentLocation!.longitude});
        way["amenity"="place_of_worship"]["religion"="muslim"](around:5000, ${_currentLocation!.latitude}, ${_currentLocation!.longitude});
      );
      out center;
    """;

    try {
      final response = await http.post(
        Uri.parse('https://overpass-api.de/api/interpreter'),
        body: query,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        setState(() {
          _mosques = elements
              .map((e) {
                final lat = e['lat'] ?? e['center']?['lat'];
                final lon = e['lon'] ?? e['center']?['lon'];
                final tags = e['tags'] ?? {};

                return {
                  'id': e['id'].toString(),
                  'name': tags['name'] ?? 'Masjid',
                  'lat': lat,
                  'lon': lon,
                  'tags': tags,
                  'distance': _calculateDistance(lat, lon),
                };
              })
              .where((m) => m['lat'] != null && m['lon'] != null)
              .toList();

          // Sort by distance
          _mosques.sort(
            (a, b) =>
                (a['distance'] as double).compareTo(b['distance'] as double),
          );

          _filteredMosques = List.from(_mosques); // Initialize filtered list
        });
      }
    } catch (e) {
      debugPrint('Error fetching mosques: $e');
    }
  }

  double _calculateDistance(double lat, double lon) {
    if (_currentLocation == null) return 0;
    return Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      lat,
      lon,
    );
  }

  Future<void> _launchMaps(double lat, double lon) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lon',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 1. Map Layer
          if (_currentLocation != null)
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation!,
                initialZoom: 15.0,
                onTap: (_, p) => setState(() => _selectedMosqueId = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.example.almuchtariyah_app',
                ),
                MarkerLayer(
                  markers: [
                    // User Location (Pulsing)
                    Marker(
                      point: _currentLocation!,
                      width: 60,
                      height: 60,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 20 * _pulseAnimation.value,
                                height: 20 * _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade500,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    // Mosque Markers
                    ..._filteredMosques.map((mosque) {
                      final isSelected = _selectedMosqueId == mosque['id'];
                      return Marker(
                        point: LatLng(mosque['lat'], mosque['lon']),
                        width: 50,
                        height: 50,
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _selectedMosqueId = mosque['id']);
                            _mapController.move(
                              LatLng(mosque['lat'], mosque['lon']),
                              16,
                            );
                          },
                          child: Column(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: isSelected ? 40 : 30,
                                height: isSelected ? 40 : 30,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : (isDark
                                            ? const Color(0xFF1F2937)
                                            : Colors.white),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.mosque,
                                  size: isSelected ? 24 : 18,
                                  color: isSelected
                                      ? Colors.black
                                      : AppColors.primary,
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),

          // 2. Search & Filter Overlay (Top)
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Search Bar
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1F2937).withValues(alpha: 0.9)
                                : Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey[200]!,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() {
                                if (value.isEmpty) {
                                  _filteredMosques = List.from(_mosques);
                                } else {
                                  _filteredMosques = _mosques.where((m) {
                                    final name = (m['name'] as String)
                                        .toLowerCase();
                                    return name.contains(value.toLowerCase());
                                  }).toList();
                                }
                                // Clear selection if search changes results significantly
                                // _selectedMosqueId = null;
                              });
                            },
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Cari masjid terdekat...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[500],
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: AppColors.primary,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Back Button
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1F2937).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.home_rounded,
                            color: AppColors.primary,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip('Buka Sekarang', true, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ada Tempat Wudhu', false, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Parkir Luas', false, isDark),
                      const SizedBox(width: 8),
                      _buildFilterChip('Ramah Anak', false, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Card (Details)
          if (_selectedMosqueId != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildMosqueCard(
                _mosques.firstWhere((m) => m['id'] == _selectedMosqueId),
                isDark,
              ),
            ),

          // Floating Action Button (Recenter)
          if (_selectedMosqueId == null && _currentLocation != null)
            Positioned(
              right: 16,
              bottom: 32,
              child: FloatingActionButton(
                onPressed: () {
                  _mapController.move(_currentLocation!, 15);
                },
                backgroundColor: isDark
                    ? const Color(0xFF1F2937)
                    : Colors.white,
                child: Icon(Icons.my_location, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, bool isDark) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary
            : (isDark
                  ? const Color(0xFF1F2937).withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.9)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.primary
              : (isDark ? Colors.grey[800]! : Colors.grey[200]!),
        ),
        boxShadow: [
          if (isSelected)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected
              ? const Color(0xFF11221C)
              : (isDark ? Colors.white : Colors.black87),
        ),
      ),
    );
  }

  Widget _buildMosqueCard(Map<String, dynamic> mosque, bool isDark) {
    final distance = (mosque['distance'] / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mosque['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$distance km',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.mosque, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _launchMaps(mosque['lat'], mosque['lon']),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.directions, size: 20),
                  label: const Text(
                    'Petunjuk Arah',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => setState(() => _selectedMosqueId = null),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.grey[800] : Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: Icon(
                  Icons.close,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
