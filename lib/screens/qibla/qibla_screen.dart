import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../services/prayer_times_service.dart';

/// Qibla Compass Screen - Updated with Real Data & Aladhan API
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin {
  double _compassHeading = 0;
  // Debug vars removed
  double _qiblaDirection = 0; // Fetched from API
  double _distanceToKaaba = 0;
  String _currentLocation = 'Mencari Lokasi...';
  bool _isAligned = false;
  bool _hapticEnabled = true;
  final bool _hasCompass = true;
  StreamSubscription<CompassEvent>? _compassSubscription;
  late AnimationController _pulseController;
  bool _hasMagnetometer = false;
  bool _hasAccelerometer = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    // Fetch data and request permissions first
    _initQiblaData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _compassSubscription?.cancel();
    super.dispose();
  }

  void _startCompassListener() {
    _compassSubscription?.cancel();

    // Check Sensors Plus first to see if hardware exists
    magnetometerEventStream().first
        .then((_) {
          if (mounted && !_hasMagnetometer) {
            setState(() => _hasMagnetometer = true);
          }
        })
        .catchError((_) {});

    accelerometerEventStream().first
        .then((_) {
          if (mounted && !_hasAccelerometer) {
            setState(() => _hasAccelerometer = true);
          }
        })
        .catchError((_) {});
    if (FlutterCompass.events == null) {
      debugPrint("FlutterCompass.events is NULL");
      return;
    }

    _compassSubscription = FlutterCompass.events!.listen((event) {
      if (mounted) {
        setState(() {
          _compassHeading = event.heading ?? 0;

          if (_qiblaDirection != 0) {
            final diff = (_compassHeading - _qiblaDirection).abs();
            final normalizedDiff = diff > 180 ? 360 - diff : diff;
            final isAlignedNow = normalizedDiff < 3;

            if (isAlignedNow && !_isAligned) {
              // Just entered alignment
              _isAligned = true;
              if (_hapticEnabled) {
                HapticFeedback.heavyImpact();
                // Fallback for devices that don't support heavyImpact well
                Future.delayed(const Duration(milliseconds: 150), () {
                  if (mounted && _isAligned) HapticFeedback.vibrate();
                });
              }
            } else if (!isAlignedNow && _isAligned) {
              // Just left alignment
              _isAligned = false;
            }
          }
        });
      }
    });
  }

  // Note: _showErrorSnackBar removed as it was unused and causing lints

  Future<void> _initQiblaData() async {
    try {
      if (mounted) setState(() => _currentLocation = 'Cek Izin...');

      // Explicitly request permissions via PermissionHandler
      // This is often more reliable than Geolocator for 'Location' generally
      await [Permission.locationWhenInUse, Permission.location].request();

      if (await Permission.location.isDenied) {
        if (mounted) {
          setState(() => _currentLocation = 'Izin Lokasi Ditolak User');
        }
      }

      // Attempt to get position even if denied (sometimes "WhenInUse" is enough)
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        // Ignore fallback
      }

      // Start Compass Listener REGARDLESS of position
      // Compass might need location permission, but doesn't necessarily need 'position' data to start rotating
      _startCompassListener();

      if (position == null) {
        if (mounted) {
          setState(() => _currentLocation = 'Posisi tidak dapat diambil');
        }
        return;
      }

      if (mounted) setState(() => _currentLocation = 'Data Kiblat...');

      final qiblaDir = await PrayerTimesService.getQiblaDirection(
        position.latitude,
        position.longitude,
      );

      final distanceMeters = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        21.422487,
        39.826206,
      );

      if (mounted) {
        setState(() {
          _qiblaDirection = qiblaDir ?? 0;
          _distanceToKaaba = distanceMeters / 1000;
          _currentLocation = 'Lokasi Terdeteksi';
        });
      }
    } catch (e) {
      debugPrint('Error initializing: $e');
      if (mounted) {
        setState(() {
          _currentLocation = 'Gagal';
        });
      }
    }
  }

  // _determinePosition removed as we use PermissionHandler directly now

  void _calibrate() {
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Kalibrasi kompas... Gerakkan perangkat dalam pola angka 8',
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final needleRotation = _qiblaDirection - _compassHeading;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF11211b)
          : const Color(0xFFF6F8F7),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isDark),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Location Chip
                    _buildLocationChip(
                      isDark,
                    ).animate().fadeIn(duration: 300.ms),

                    // Compass
                    _buildCompass(context, isDark, needleRotation)
                        .animate(delay: 100.ms)
                        .fadeIn(duration: 400.ms)
                        .scale(
                          begin: const Offset(0.9, 0.9),
                          end: const Offset(1, 1),
                        ),

                    // Degree Display
                    _buildDegreeDisplay(
                      context,
                      isDark,
                    ).animate(delay: 200.ms).fadeIn(duration: 300.ms),

                    // Settings Card
                    _buildSettingsCard(context, isDark)
                        .animate(delay: 300.ms)
                        .fadeIn(duration: 300.ms)
                        .slideY(begin: 0.1, end: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF11211b).withValues(alpha: 0.95)
            : const Color(0xFFF6F8F7).withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(
              context,
              '/main',
              (route) => false,
            ),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : const Color(0xFF0e1b16),
              size: 20,
            ),
          ),
          Expanded(
            child: Text(
              'Kompas Kiblat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0e1b16),
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: Icon(
              Icons.settings,
              color: isDark ? Colors.white : const Color(0xFF0e1b16),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationChip(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c332b) : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.near_me, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            _currentLocation.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompass(
    BuildContext context,
    bool isDark,
    double needleRotation,
  ) {
    // If no compass sensor, show message
    if (!_hasCompass) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.compass_calibration_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              "Sensor Kompas Tidak Terdeteksi",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Fitur kompas memerlukan sensor gnetometer perangkat.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final size = MediaQuery.of(context).size.width * 0.75;
    final compassSize = size.clamp(280.0, 320.0);

    return Column(
      children: [
        // Arrow indicator at top
        Icon(Icons.arrow_drop_down, size: 32, color: AppColors.primary),

        // Compass container
        Container(
          width: compassSize,
          height: compassSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1c332b) : Colors.white,
            border: Border.all(
              color: isDark ? Colors.grey.shade800 : Colors.white,
              width: 4,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.1),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Inner border
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),

              // Compass dial (rotates with heading)
              Transform.rotate(
                angle: -_compassHeading * (math.pi / 180),
                child: SizedBox(
                  width: compassSize - 16,
                  height: compassSize - 16,
                  child: CustomPaint(
                    painter: CompassDialPainter(isDark: isDark),
                  ),
                ),
              ),

              // Cardinal directions
              Positioned(
                top: 16,
                child: Text(
                  'N',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade500,
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                child: Text(
                  'S',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Positioned(
                left: 16,
                child: Text(
                  'W',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),
              Positioned(
                right: 16,
                child: Text(
                  'E',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade400,
                  ),
                ),
              ),

              // Center dot
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade200,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark ? Colors.grey.shade500 : Colors.grey.shade300,
                  ),
                ),
              ),

              // Qibla Needle (points to Qibla)
              Transform.rotate(
                angle: needleRotation * (math.pi / 180),
                child: SizedBox(
                  width: 6,
                  height: compassSize - 48,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Upper needle (Qibla direction) - green
                      Positioned(
                        top: 24,
                        child: Container(
                          width: 6,
                          height: (compassSize - 48) * 0.42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                AppColors.primary,
                                const Color(0xFF34eeb0),
                              ],
                            ),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(3),
                              topRight: Radius.circular(3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 15,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 2,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Lower needle - gray
                      Positioned(
                        bottom: 24,
                        child: Container(
                          width: 6,
                          height: (compassSize - 48) * 0.42,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade300,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(3),
                              bottomRight: Radius.circular(3),
                            ),
                          ),
                        ),
                      ),

                      // Ka'bah icon at tip
                      Positioned(top: 4, child: _buildKaabaIcon(isDark)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKaabaIcon(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey.shade800 : Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
        ],
      ),
      child: Container(
        width: 16,
        height: 14,
        decoration: BoxDecoration(
          color: isDark ? Colors.black : const Color(0xFF1f2937),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 0,
              right: 0,
              child: Container(height: 3, color: const Color(0xFFfbbf24)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDegreeDisplay(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Large degree display
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _qiblaDirection.toInt().toString(),
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0e1b16),
                letterSpacing: -2,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '°',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 4),

        // Distance info
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Jarak ke Ka\'bah',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade600 : Colors.grey.shade300,
                shape: BoxShape.circle,
              ),
            ),
            Text(
              '${_distanceToKaaba.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} km',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c332b) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        children: [
          // Haptic Toggle Row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.vibration,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Getar Saat Lurus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0e1b16),
                        ),
                      ),
                      Text(
                        'Respon haptic saat akurat',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Switch
                Switch(
                  value: _hapticEnabled,
                  onChanged: (value) {
                    HapticFeedback.lightImpact();
                    setState(() => _hapticEnabled = value);
                  },
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: isDark
                ? Colors.grey.shade800.withValues(alpha: 0.5)
                : Colors.grey.shade50,
            indent: 12,
            endIndent: 12,
          ),

          // Calibration Button (Existing)
          InkWell(
            onTap: _calibrate,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sync,
                    size: 18,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Kalibrasi Ulang',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade300
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for compass dial
class CompassDialPainter extends CustomPainter {
  final bool isDark;

  CompassDialPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final tickPaint = Paint()
      ..color = isDark ? Colors.grey.shade600 : Colors.grey.shade300
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    final majorTickPaint = Paint()
      ..color = isDark ? Colors.grey.shade500 : Colors.grey.shade400
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    // Draw tick marks
    for (int i = 0; i < 360; i += 10) {
      final isMajor = i % 30 == 0;
      final tickLength = isMajor ? 12.0 : 6.0;
      final angle = i * (math.pi / 180);

      final startPoint = Offset(
        center.dx + (radius - tickLength - 8) * math.sin(angle),
        center.dy - (radius - tickLength - 8) * math.cos(angle),
      );

      final endPoint = Offset(
        center.dx + (radius - 8) * math.sin(angle),
        center.dy - (radius - 8) * math.cos(angle),
      );

      canvas.drawLine(
        startPoint,
        endPoint,
        isMajor ? majorTickPaint : tickPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
