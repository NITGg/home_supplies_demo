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

/// A static (non-interactive) monochrome OSM map showing three pins:
///   • Courier current location  (blue dot)
///   • Pickup                    (store icon, kPrimaryColor)
///   • Delivery                  (pin icon,   green)
///
/// The camera is fitted to the tightest bounding box that contains all three
/// visible points, with enough padding so no marker icon is clipped.
/// A real road-following route is drawn between pickup → delivery via OSRM.
class RouteMapWidget extends StatefulWidget {
  final double pickupLat;
  final double pickupLng;
  final double deliveryLat;
  final double deliveryLng;

  const RouteMapWidget({
    super.key,
    required this.pickupLat,
    required this.pickupLng,
    required this.deliveryLat,
    required this.deliveryLng,
  });

  @override
  State<RouteMapWidget> createState() => _RouteMapWidgetState();
}

class _RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _mapController = MapController();

  /// Non-null once location resolves; null while loading or if denied.
  Position? _userPosition;
  bool _locationLoading = true;

  /// Road route polyline from OSRM (pickup → delivery); null while fetching.
  List<LatLng>? _routePoints;

  /// Road route from courier current location → pickup; null while fetching.
  List<LatLng>? _userToPickupPoints;

  // ── Convenience getters ──────────────────────────────────────────────────

  LatLng get _pickup   => LatLng(widget.pickupLat,   widget.pickupLng);
  LatLng get _delivery => LatLng(widget.deliveryLat, widget.deliveryLng);
  LatLng? get _user    => _userPosition == null
      ? null
      : LatLng(_userPosition!.latitude, _userPosition!.longitude);

  /// Bounding box that contains all non-null points.
  ///
  /// [extra] — user position once resolved.
  ///
  /// The [padding] passed to [CameraFit.bounds] handles pixel-level clearance
  /// for the marker icons (the tallest icon is 54 px, add comfortable buffer).
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
    _fetchRoute();
    _fetchLocation();
  }

  /// Fetches road routes:
  ///   1. pickup → delivery (always)
  ///   2. user → pickup     (only once user position is known, called from [_fetchLocation])
  Future<void> _fetchRoute() async {
    final points = await _osrmRoute(
      fromLat: widget.pickupLat, fromLng: widget.pickupLng,
      toLat: widget.deliveryLat, toLng: widget.deliveryLng,
    );
    if (mounted && points != null) setState(() => _routePoints = points);
  }

  Future<void> _fetchUserToPickupRoute(Position from) async {
    final points = await _osrmRoute(
      fromLat: from.latitude,   fromLng: from.longitude,
      toLat: widget.pickupLat,  toLng: widget.pickupLng,
    );
    if (mounted && points != null) setState(() => _userToPickupPoints = points);
  }

  /// Calls the free OSRM public API and returns a decoded polyline, or null on failure.
  Future<List<LatLng>?> _osrmRoute({
    required double fromLat, required double fromLng,
    required double toLat,   required double toLng,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
            '$fromLng,$fromLat;$toLng,$toLat'
            '?overview=full&geometries=geojson',
      );
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final body      = jsonDecode(response.body) as Map<String, dynamic>;
      final routes    = body['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final coords = (routes[0]['geometry'] as Map<String, dynamic>?)?['coordinates'] as List?;
      if (coords == null) return null;

      return coords
          .cast<List>()
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Fetches the courier's current position via [LocationService].
  Future<void> _fetchLocation() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final position = await LocationService.instance.getCurrentLocation(
        context: context,
      );
      if (!mounted) return;
      setState(() {
        _userPosition = position;
        _locationLoading = false;
      });

      // Re-fit the camera to include all three points once location is known.
      if (position != null) {
        _fetchUserToPickupRoute(position);
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _computeBounds(extra: position),
            padding: const EdgeInsets.fromLTRB(44, 54, 44, 54),
            // Prevent zooming out too far when the user is far from the route.
            maxZoom: 25,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // Initial fit covers pickup + delivery only.
                    // Padding is large enough for the tallest icon (54 px).
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

                    // ── User → Pickup route (light translucent blue) ──────
                    if (_userToPickupPoints != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _userToPickupPoints!,
                            strokeWidth: 4.0,
                            color: Colors.blue.withOpacity(0.35),
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                    // ── Road route polyline (pickup → delivery) ───────────
                    // Shown only after OSRM responds. Falls back to nothing
                    // if the request fails — no straight fallback line.
                    if (_routePoints != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints!,
                            strokeWidth: 4.0,
                            color: AppColors.kPrimaryColor.withOpacity(0.85),
                            // Rounded caps make road routes look more natural.
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                    // ── Markers ───────────────────────────────────────────
                    MarkerLayer(
                      markers: [
                        // Courier location — blue dot
                        if (_user != null) _buildUserMarker(_user!),

                        // Pickup
                        _buildIconMarker(
                          point: _pickup,
                          icon: Icons.store_outlined,
                          color: AppColors.kPrimaryColor,
                          label: l10n.pickupLocation,
                        ),

                        // Delivery
                        _buildIconMarker(
                          point: _delivery,
                          icon: Icons.location_on,
                          color: Colors.green,
                          label: l10n.deliveryLocation,
                        ),
                      ],
                    ),

                    // ── OSM attribution (required by tile usage policy) ───
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),

                // ── Loading badge while awaiting user location ────────────
                if (_locationLoading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(8),
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
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Marker builders ──────────────────────────────────────────────────────

  /// Blue dot for the courier's own position.
  Marker _buildUserMarker(LatLng point) {
    return Marker(
      point: point,
      width: 24,
      height: 24,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }

  /// Icon pin with a triangular tail — tip sits exactly on the coordinate.
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
      alignment: Alignment.bottomCenter, // pin tip sits on the coordinate
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