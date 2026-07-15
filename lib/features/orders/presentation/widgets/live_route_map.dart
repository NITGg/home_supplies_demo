import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../../core/style/app_colors.dart';
import '../../../../core/style/text_styles.dart';
import '../../../../core/utils/location_service.dart';
import '../../../../l10n/app_localizations.dart';

/// A live map that shows the courier's position updating on a fixed interval.
///
/// Three pins are rendered:
///   • Courier   – animated blue dot, refreshed every [locationUpdateInterval]
///   • Pickup    – store icon  (kPrimaryColor)
///   • Delivery  – pin  icon  (green)
///
/// Two road-following polylines are drawn via OSRM:
///   • Courier → Pickup   (light blue, re-fetched whenever the courier moves
///                          more than [routeRefetchThresholdMeters])
///   • Pickup  → Delivery (primary colour, fetched once on init)
class LiveRouteMapWidget extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;

  /// How often the courier location is polled.
  final Duration locationUpdateInterval;

  /// Minimum distance (metres) the courier must move before the
  /// courier→pickup route is re-fetched from OSRM.
  final double routeRefetchThresholdMeters;

  const LiveRouteMapWidget({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.locationUpdateInterval = const Duration(seconds: 15),
    this.routeRefetchThresholdMeters = 100,
  });

  @override
  State<LiveRouteMapWidget> createState() => _LiveRouteMapWidgetState();
}

class _LiveRouteMapWidgetState extends State<LiveRouteMapWidget>
    with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();

  Position? _userPosition;
  bool _locationLoading = true;

  /// Pickup → Delivery road polyline (fetched once).
  List<LatLng>? _pickupToDeliveryPoints;

  /// Courier → Pickup road polyline (re-fetched on movement).
  List<LatLng>? _userToPickupPoints;

  /// Last position used to fetch the courier→pickup route.
  Position? _lastRouteFetchPosition;

  Timer? _locationTimer;

  /// Pulse animation for the courier dot.
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Convenience getters ──────────────────────────────────────────────────

  LatLng get _pickup => LatLng(widget.pickupLat, widget.pickupLng);
  LatLng get _delivery => LatLng(widget.deliveryLat, widget.deliveryLng);
  LatLng? get _user => _userPosition == null
      ? null
      : LatLng(_userPosition!.latitude, _userPosition!.longitude);

  LatLngBounds _computeBounds({Position? extra}) {
    final points = <LatLng>[
      LatLng(widget.pickupLat, widget.pickupLng),
      LatLng(widget.deliveryLat, widget.deliveryLng),
    ];

    if (extra != null) {
      points.add(LatLng(extra.latitude, extra.longitude));
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }

    // 🚨 FIX: prevent zero-area bounds
    const epsilon = 0.0001;

    if ((maxLat - minLat).abs() < epsilon) {
      minLat -= epsilon;
      maxLat += epsilon;
    }

    if ((maxLng - minLng).abs() < epsilon) {
      minLng -= epsilon;
      maxLng += epsilon;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    // Pulse animation for the courier dot.
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchPickupToDeliveryRoute();
    _fetchLocationAndStartTimer();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── Location polling ─────────────────────────────────────────────────────

  Future<void> _fetchLocationAndStartTimer() async {
    // Immediate first fetch (inside post-frame so context is valid).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _updateLocation();

      // Start the periodic timer after the first fetch.
      _locationTimer = Timer.periodic(
        widget.locationUpdateInterval,
            (_) => _updateLocation(),
      );
    });
  }

  Future<void> _updateLocation() async {
    if (!mounted) return;

    final position = await LocationService.instance.getCurrentLocation(
      context: context,
    );
    if (!mounted || position == null) {
      if (mounted) setState(() => _locationLoading = false);
      return;
    }

    final isFirstFetch = _userPosition == null;

    setState(() {
      _userPosition = position;
      _locationLoading = false;
    });

    // Re-fit camera on first successful fix so all three pins are visible.
    if (isFirstFetch) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _computeBounds(extra: position),
          padding: const EdgeInsets.fromLTRB(44, 54, 44, 54),
          maxZoom: 16,
        ),
      );
    }

    // Decide whether to re-fetch the courier→pickup route.
    final shouldRefetch = _lastRouteFetchPosition == null ||
        Geolocator.distanceBetween(
          _lastRouteFetchPosition!.latitude,
          _lastRouteFetchPosition!.longitude,
          position.latitude,
          position.longitude,
        ) >=
            widget.routeRefetchThresholdMeters;

    if (shouldRefetch) {
      _lastRouteFetchPosition = position;
      _fetchUserToPickupRoute(position);
    }
  }

  // ── OSRM route fetching ──────────────────────────────────────────────────

  Future<void> _fetchPickupToDeliveryRoute() async {
    final points = await _osrmRoute(
      fromLat: widget.pickupLat,
      fromLng: widget.pickupLng,
      toLat: widget.deliveryLat,
      toLng: widget.deliveryLng,
    );
    if (mounted && points != null) {
      setState(() => _pickupToDeliveryPoints = points);
    }
  }

  Future<void> _fetchUserToPickupRoute(Position from) async {
    final points = await _osrmRoute(
      fromLat: from.latitude,
      fromLng: from.longitude,
      toLat: widget.pickupLat,
      toLng: widget.pickupLng,
    );
    if (mounted && points != null) {
      setState(() => _userToPickupPoints = points);
    }
  }

  Future<List<LatLng>?> _osrmRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '$fromLng,$fromLat;$toLng,$toLat'
            '?overview=full&geometries=geojson',
      );
      final response =
      await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final coords =
      (routes[0]['geometry'] as Map<String, dynamic>?)?['coordinates']
      as List?;
      if (coords == null) return null;

      return coords
          .cast<List>()
          .map((c) =>
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 260,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: CameraFit.bounds(
                      bounds: _computeBounds(),
                      padding: const EdgeInsets.fromLTRB(52, 72, 52, 72),
                    ),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    // ── Monochrome OSM tiles ──────────────────────────────
                    ColorFiltered(
                      colorFilter: const ColorFilter.matrix(<double>[
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0.2126, 0.7152, 0.0722, 0, 0,
                        0,      0,      0,      1, 0,
                      ]),
                      child: TileLayer(
                        urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.tawreedat.courier',
                        retinaMode:
                        MediaQuery.of(context).devicePixelRatio > 1,
                      ),
                    ),

                    // ── Courier → Pickup polyline (translucent blue) ──────
                    if (_userToPickupPoints != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _userToPickupPoints!,
                            strokeWidth: 4.0,
                            color: Colors.blue.withOpacity(0.40),
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                    // ── Pickup → Delivery polyline (primary colour) ───────
                    if (_pickupToDeliveryPoints != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _pickupToDeliveryPoints!,
                            strokeWidth: 4.0,
                            color:
                            AppColors.kPrimaryColor.withOpacity(0.85),
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                    // ── Markers ───────────────────────────────────────────
                    MarkerLayer(
                      markers: [
                        if (_user != null) _buildUserMarker(_user!),
                        _buildIconMarker(
                          point: _pickup,
                          icon: Icons.store_outlined,
                          color: AppColors.kPrimaryColor,
                          label: l10n.pickupLocation,
                        ),
                        _buildIconMarker(
                          point: _delivery,
                          icon: Icons.location_on,
                          color: Colors.green,
                          label: l10n.deliveryLocation,
                        ),
                      ],
                    ),

                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                // ── Location loading badge ────────────────────────────────
                if (_locationLoading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            l10n.gettingLocation,
                            style: AppTextStyles.regular14.copyWith(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── "Live" badge ──────────────────────────────────────────
                // if (!_locationLoading && _userPosition != null)
                //   Positioned(
                //     top: 8,
                //     right: 8,
                //     child: Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 8, vertical: 4),
                //       decoration: BoxDecoration(
                //         color: Colors.white.withOpacity(0.9),
                //         borderRadius: BorderRadius.circular(8),
                //         boxShadow: [
                //           BoxShadow(
                //             color: Colors.black.withOpacity(0.08),
                //             blurRadius: 6,
                //           ),
                //         ],
                //       ),
                //       child: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           Container(
                //             width: 7,
                //             height: 7,
                //             decoration: BoxDecoration(
                //               color: Colors.green.shade500,
                //               shape: BoxShape.circle,
                //             ),
                //           ),
                //           const SizedBox(width: 5),
                //           Text(
                //             'Live',
                //             style: AppTextStyles.regular14.copyWith(
                //               fontSize: 11,
                //               color: Colors.grey.shade700,
                //               fontWeight: FontWeight.w600,
                //             ),
                //           ),
                //         ],
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Marker builders ──────────────────────────────────────────────────────

  /// Animated pulsing blue dot for the courier.
  Marker _buildUserMarker(LatLng point) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              Container(
                width: 36 * (_pulseAnimation.value / 1.6),
                height: 36 * (_pulseAnimation.value / 1.6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(
                    0.25 * (1.6 - _pulseAnimation.value) / 0.6,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              // Inner solid dot
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: Colors.blue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Icon pin with triangular tail – tip sits exactly on the coordinate.
  Marker _buildIconMarker({
    required LatLng point,
    required IconData icon,
    required Color color,
    required String label,
  }) {
    return Marker(
      point: point,
      width: 44,
      height: 54,
      alignment: Alignment.bottomCenter,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          CustomPaint(
            size: const Size(12, 8),
            painter: _PinTailPainter(color: color),
          ),
        ],
      ),
    );
  }
}

// ── Pin tail painter ─────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = dart_ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}