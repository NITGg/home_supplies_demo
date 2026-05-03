import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as dart_ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:lottie/lottie.dart' hide Marker;

import '../../../../core/style/text_styles.dart';
import '../../../../l10n/app_localizations.dart';

class CustomerLiveRouteMapWidget extends StatefulWidget {
  final double courierLat;
  final double courierLng;
  final double deliveryLat;
  final double deliveryLng;
  final double routeRefetchThresholdMeters;

  /// Fine-tunes the courier asset's facing direction on screen, in degrees
  /// clockwise-positive.
  ///
  /// The camera is already rotated so the delivery is to the right, but if
  /// the Lottie animation's default facing direction isn't exactly east you
  /// can compensate here without touching any other logic.
  ///
  /// • Positive value  → rotates the asset clockwise  (asset was pointing too far left)
  /// • Negative value  → rotates the asset CCW         (asset was pointing too far right)
  ///
  /// Tune this once for your specific Lottie file and leave it fixed.
  final double assetFacingOffsetDeg;

  /// Called when the first finger touches the map — parent should freeze its scroll.
  final VoidCallback? onInteractionStart;

  /// Called when all fingers lift — parent can restore scrolling.
  final VoidCallback? onInteractionEnd;

  const CustomerLiveRouteMapWidget({
    super.key,
    required this.courierLat,
    required this.courierLng,
    required this.deliveryLat,
    required this.deliveryLng,
    this.routeRefetchThresholdMeters = 80,
    this.assetFacingOffsetDeg = 0,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  @override
  State<CustomerLiveRouteMapWidget> createState() =>
      _CustomerLiveRouteMapWidgetState();
}

class _CustomerLiveRouteMapWidgetState
    extends State<CustomerLiveRouteMapWidget> {
  final MapController _mapController = MapController();

  List<LatLng>? _routePoints;
  ({double lat, double lng})? _lastFetchedAt;
  bool _isFirstRender = true;

  // Tracks how many pointers are currently on this widget.
  int _pointerCount = 0;

  // Camera rotation in degrees (clockwise from north).
  // Kept as a field so initState, didUpdateWidget, and build all share
  // the same value without recomputing it multiple times.
  double _mapRotationDeg = 0;

  // ── Convenience ──────────────────────────────────────────────────────────

  LatLng get _courier => LatLng(widget.courierLat, widget.courierLng);
  LatLng get _delivery => LatLng(widget.deliveryLat, widget.deliveryLng);

  LatLngBounds get _bounds {
    final points = [_courier, _delivery];
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    const epsilon = 0.0001;
    if ((maxLat - minLat).abs() < epsilon) {
      minLat -= epsilon;
      maxLat += epsilon;
    }
    if ((maxLng - minLng).abs() < epsilon) {
      minLng -= epsilon;
      maxLng += epsilon;
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  /// Bearing from [from] to [to] in radians, clockwise from north.
  double _bearingRad(LatLng from, LatLng to) {
    final lat1 = _toRad(from.latitude);
    final lat2 = _toRad(to.latitude);
    final dLng = _toRad(to.longitude - from.longitude);
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return math.atan2(y, x);
  }

  /// Converts the courier→delivery bearing into a map camera rotation so
  /// the delivery point is always rendered to the right of the courier.
  ///
  /// flutter_map uses **clockwise-positive** degrees (0 = north up).
  /// When the map rotates clockwise by R°, bearing B° appears at screen
  /// angle (R + B) from the top.  We want delivery (bearing B) at
  /// screen-right (90°):
  ///
  ///   R + B = 90  →  R = 90 − B
  ///
  /// Examples:
  ///   B =   0° (north) → R = +90° → north moves to right  ✓
  ///   B =  90° (east)  → R =   0° → east stays at right   ✓
  ///   B = 180° (south) → R = −90° → south moves to right  ✓
  double _computeMapRotationDeg() =>
      90 - _bearingRad(_courier, _delivery) * 180 / math.pi;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _mapRotationDeg = _computeMapRotationDeg();
    _fetchRoute();
  }

  @override
  void didUpdateWidget(CustomerLiveRouteMapWidget old) {
    super.didUpdateWidget(old);

    final courierMoved = old.courierLat != widget.courierLat ||
        old.courierLng != widget.courierLng;
    if (!courierMoved) return;

    // Recompute rotation whenever the courier moves so the delivery
    // stays pinned to the right of the screen.
    _mapRotationDeg = _computeMapRotationDeg();

    if (!_isFirstRender) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: _bounds,
          padding: const EdgeInsets.all(56),
          maxZoom: 18,
        ),
      );
      // fitCamera only updates zoom + center; rotation must be set explicitly.
      _mapController.rotate(_mapRotationDeg);
    }

    final shouldRefetch = _lastFetchedAt == null ||
        _haversineDistance(
          _lastFetchedAt!.lat,
          _lastFetchedAt!.lng,
          widget.courierLat,
          widget.courierLng,
        ) >= widget.routeRefetchThresholdMeters;

    if (shouldRefetch) _fetchRoute();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  // ── Pointer tracking helpers ─────────────────────────────────────────────

  void _onPointerDown(PointerDownEvent _) {
    _pointerCount++;
    if (_pointerCount == 1) widget.onInteractionStart?.call();
  }

  void _onPointerUp(PointerUpEvent _) {
    _pointerCount = (_pointerCount - 1).clamp(0, 99);
    if (_pointerCount == 0) widget.onInteractionEnd?.call();
  }

  void _onPointerCancel(PointerCancelEvent _) {
    _pointerCount = (_pointerCount - 1).clamp(0, 99);
    if (_pointerCount == 0) widget.onInteractionEnd?.call();
  }

  // ── Route fetching ───────────────────────────────────────────────────────

  Future<void> _fetchRoute() async {
    _lastFetchedAt = (lat: widget.courierLat, lng: widget.courierLng);

    final points = await _osrmRoute(
      fromLat: widget.courierLat,
      fromLng: widget.courierLng,
      toLat: widget.deliveryLat,
      toLng: widget.deliveryLng,
    );

    if (!mounted) return;
    setState(() {
      _routePoints = points;
      if (_isFirstRender) _isFirstRender = false;
    });
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

  // ── Haversine ────────────────────────────────────────────────────────────

  double _haversineDistance(
      double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _toRad(double deg) => deg * math.pi / 180;

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerCancel,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      // Rotate the camera so the courier→delivery axis is
                      // horizontal and delivery is always on the right.
                      // flutter_map markers do NOT rotate with the map, so
                      // the Lottie asset's default east-facing direction
                      // naturally points at the delivery — no Transform needed.
                      initialRotation: _mapRotationDeg,
                      initialCameraFit: CameraFit.bounds(
                        bounds: _bounds,
                        padding: const EdgeInsets.all(56),
                        maxZoom: 18,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.drag |
                        InteractiveFlag.pinchZoom |
                        InteractiveFlag.doubleTapZoom |
                        InteractiveFlag.scrollWheelZoom,
                      ),
                    ),
                    children: [
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
                          userAgentPackageName: 'com.tawreedat.go',
                          retinaMode:
                          MediaQuery.of(context).devicePixelRatio > 1,
                        ),
                      ),
                      if (_routePoints != null)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints!,
                              strokeWidth: 4.0,
                              color: Colors.blueAccent.withOpacity(0.80),
                              strokeCap: StrokeCap.round,
                              strokeJoin: StrokeJoin.round,
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          // No bearing argument — the camera rotation
                          // already aligns the asset with the delivery.
                          _buildCourierMarker(_courier),
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

                  // ── "Live" badge ──────────────────────────────────────
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.93),
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
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: Colors.green.shade500,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Live',
                            style: AppTextStyles.regular14.copyWith(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Marker builders ──────────────────────────────────────────────────────

  /// Builds the courier marker.
  ///
  /// The camera is already rotated so the delivery is always to the right on
  /// screen.  flutter_map markers stay screen-aligned (they don't rotate with
  /// the map), so the Lottie's default east-facing direction points at the
  /// delivery automatically.
  ///
  /// [widget.assetFacingOffsetDeg] compensates for any difference between the
  /// animation's actual default facing direction and true east.
  Marker _buildCourierMarker(LatLng point) {
    final offsetRad = widget.assetFacingOffsetDeg * math.pi / 180;
    return Marker(
      point: point,
      width: 100,
      height: 100,
      child: Transform.rotate(
        angle: offsetRad,
        child: Lottie.asset(
          'assets/animation_json/courier_on_the_way.json',
          width: 100,
          height: 100,
          repeat: true,
          frameRate: FrameRate(30),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

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