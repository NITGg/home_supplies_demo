// lib/core/utils/area_boundary_validator.dart

import 'dart:math' hide log;
import 'dart:developer';

class AreaBoundaryValidator {
  /// Parses a single boundary point from either format:
  ///   "30.05,31.33"  →  LatLng
  ///   {"lat": 30.05, "lng": 31.33}  →  LatLng
  static _LatLng? _parsePoint(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final parts = value.split(',');
      if (parts.length != 2) return null;
      final lat = double.tryParse(parts[0].trim());
      final lng = double.tryParse(parts[1].trim());
      if (lat == null || lng == null) return null;
      return _LatLng(lat, lng);
    }

    if (value is Map) {
      final lat = (value['lat'] as num?)?.toDouble();
      final lng = (value['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) return null;
      return _LatLng(lat, lng);
    }

    return null;
  }

  /// Extracts all boundary points from the raw boundaries map,
  /// regardless of how many points (point1, point2, point3 …).
  static List<_LatLng> _extractPoints(Map<String, dynamic> boundaries) {
    final points = <_LatLng>[];
    // Sort keys so point1, point2, point3 come in order
    final sortedKeys = boundaries.keys.toList()..sort();
    for (final key in sortedKeys) {
      final p = _parsePoint(boundaries[key]);
      if (p != null) points.add(p);
    }
    return points;
  }

  /// Returns the centroid of the boundary polygon (for map centering).
  static ({double lat, double lng})? centroid(Map<String, dynamic> boundaries) {
    final points = _extractPoints(boundaries);
    if (points.isEmpty) return null;
    final lat = points.map((p) => p.lat).reduce((a, b) => a + b) / points.length;
    final lng = points.map((p) => p.lng).reduce((a, b) => a + b) / points.length;
    return (lat: lat, lng: lng);
  }

  /// Main entry point: checks whether [lat]/[lng] sits inside the area.
  ///
  /// - 2 points  →  bounding-box check (backward compat with old data)
  /// - 3+ points →  ray-casting polygon check
  static bool isPointInArea({
    required double lat,
    required double lng,
    required Map<String, dynamic> boundaries,
  }) {
    final points = _extractPoints(boundaries);

    log('🔍 AreaBoundaryValidator.isPointInArea');
    log('   pin       : ($lat, $lng)');
    log('   points    : ${points.map((p) => "(${p.lat}, ${p.lng})").toList()}');

    if (points.isEmpty) {
      log('   result    : true (no boundaries defined — permissive)');
      return true;
    }

    final bool result;
    if (points.length == 2) {
      result = _boundingBoxCheck(lat, lng, points[0], points[1]);
      log('   method    : bounding box');
    } else {
      result = _polygonCheck(lat, lng, points);
      log('   method    : ray-casting polygon');
    }

    log('   result    : $result');
    return result;
  }

  // ── Bounding-box (2-point) ──────────────────────────────────────────────

  static bool _boundingBoxCheck(
      double lat,
      double lng,
      _LatLng p1,
      _LatLng p2,
      ) {
    final minLat = min(p1.lat, p2.lat);
    final maxLat = max(p1.lat, p2.lat);
    final minLng = min(p1.lng, p2.lng);
    final maxLng = max(p1.lng, p2.lng);
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  // ── Ray-casting polygon (3+ points) ────────────────────────────────────

  static bool _polygonCheck(double lat, double lng, List<_LatLng> polygon) {
    int crossings = 0;
    final n = polygon.length;

    for (int i = 0; i < n; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % n];

      if (((a.lng <= lng && lng < b.lng) || (b.lng <= lng && lng < a.lng)) &&
          lat < (b.lat - a.lat) / (b.lng - a.lng) * (lng - a.lng) + a.lat) {
        crossings++;
      }
    }

    return crossings.isOdd;
  }
}

class _LatLng {
  final double lat;
  final double lng;
  const _LatLng(this.lat, this.lng);
}