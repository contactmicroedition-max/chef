import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

class OrganisationZone {
  const OrganisationZone({required this.points});

  static const maxAreaSquareMeters = 10000000.0;
  static const earthRadiusMeters = 6371008.8;

  final List<LatLng> points;

  Map<String, Object> toGeoJson() {
    final ring = points
        .map((point) => [point.longitude, point.latitude])
        .toList();
    if (ring.isNotEmpty &&
        (ring.first[0] != ring.last[0] || ring.first[1] != ring.last[1])) {
      ring.add(List<double>.of(ring.first));
    }
    return {
      'type': 'Polygon',
      'coordinates': [ring],
    };
  }

  factory OrganisationZone.fromGeoJson(Map<String, dynamic> geoJson) {
    if (geoJson['type'] != 'Polygon') {
      throw const FormatException('Work zone must be a GeoJSON Polygon.');
    }
    final coordinates = geoJson['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) {
      throw const FormatException('Work zone polygon coordinates are missing.');
    }
    final ring = coordinates.first;
    if (ring is! List) {
      throw const FormatException('Work zone polygon ring is invalid.');
    }
    final points = ring.map((coordinate) {
      if (coordinate is! List ||
          coordinate.length < 2 ||
          coordinate[0] is! num ||
          coordinate[1] is! num) {
        throw const FormatException('Work zone coordinate is invalid.');
      }
      return LatLng(
        (coordinate[1] as num).toDouble(),
        (coordinate[0] as num).toDouble(),
      );
    }).toList();
    if (points.length > 1 && points.first == points.last) {
      points.removeLast();
    }
    return OrganisationZone(points: points);
  }

  double get areaSquareMeters {
    if (points.length < 3) return 0;
    var sum = 0.0;
    for (var index = 0; index < points.length; index++) {
      final current = points[index];
      final next = points[(index + 1) % points.length];
      final longitudeDelta = _wrappedLongitudeDelta(
        _radians(next.longitude - current.longitude),
      );
      sum +=
          longitudeDelta *
          (2 +
              math.sin(_radians(current.latitude)) +
              math.sin(_radians(next.latitude)));
    }
    return (sum * earthRadiusMeters * earthRadiusMeters / 2).abs();
  }

  String? get validationError {
    if (points.length < 3) {
      return 'Add at least 3 points to draw a work zone.';
    }
    if (points.toSet().length != points.length) {
      return 'Remove duplicate points from the work zone.';
    }
    for (var index = 0; index < points.length; index++) {
      if (_segmentsIntersect(
        points[index],
        points[(index + 1) % points.length],
        points,
        index,
      )) {
        return 'Work zone edges must not cross.';
      }
    }
    if (areaSquareMeters <= 0) {
      return 'Work zone area must be greater than zero.';
    }
    if (areaSquareMeters > maxAreaSquareMeters) {
      return 'Work zone cannot exceed 10 square kilometres.';
    }
    return null;
  }

  bool get isValid => validationError == null;

  bool containsPoint(LatLng point) {
    if (points.length < 3) return false;
    var isInside = false;
    for (
      var index = 0, previousIndex = points.length - 1;
      index < points.length;
      previousIndex = index++
    ) {
      final current = points[index];
      final previous = points[previousIndex];
      if (_pointOnSegment(point, previous, current)) return true;
      final crossesLatitude =
          (current.latitude > point.latitude) !=
          (previous.latitude > point.latitude);
      if (crossesLatitude) {
        final crossingLongitude =
            (previous.longitude - current.longitude) *
                (point.latitude - current.latitude) /
                (previous.latitude - current.latitude) +
            current.longitude;
        if (point.longitude < crossingLongitude) isInside = !isInside;
      }
    }
    return isInside;
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  static double _wrappedLongitudeDelta(double radians) {
    if (radians > math.pi) return radians - 2 * math.pi;
    if (radians < -math.pi) return radians + 2 * math.pi;
    return radians;
  }

  static bool _segmentsIntersect(
    LatLng firstStart,
    LatLng firstEnd,
    List<LatLng> polygon,
    int firstIndex,
  ) {
    final count = polygon.length;
    for (var secondIndex = firstIndex + 1; secondIndex < count; secondIndex++) {
      if (secondIndex == firstIndex ||
          secondIndex == firstIndex + 1 ||
          (firstIndex == 0 && secondIndex == count - 1)) {
        continue;
      }
      if (_intersect(
        firstStart,
        firstEnd,
        polygon[secondIndex],
        polygon[(secondIndex + 1) % count],
      )) {
        return true;
      }
    }
    return false;
  }

  static bool _intersect(LatLng a, LatLng b, LatLng c, LatLng d) {
    final first = _orientation(a, b, c);
    final second = _orientation(a, b, d);
    final third = _orientation(c, d, a);
    final fourth = _orientation(c, d, b);
    const epsilon = 1e-12;

    if (first.abs() <= epsilon && _onSegment(a, c, b)) return true;
    if (second.abs() <= epsilon && _onSegment(a, d, b)) return true;
    if (third.abs() <= epsilon && _onSegment(c, a, d)) return true;
    if (fourth.abs() <= epsilon && _onSegment(c, b, d)) return true;
    return (first > 0) != (second > 0) && (third > 0) != (fourth > 0);
  }

  static double _orientation(LatLng a, LatLng b, LatLng c) {
    return (b.longitude - a.longitude) * (c.latitude - a.latitude) -
        (b.latitude - a.latitude) * (c.longitude - a.longitude);
  }

  static bool _onSegment(LatLng a, LatLng point, LatLng b) {
    const epsilon = 1e-12;
    return point.longitude >= math.min(a.longitude, b.longitude) - epsilon &&
        point.longitude <= math.max(a.longitude, b.longitude) + epsilon &&
        point.latitude >= math.min(a.latitude, b.latitude) - epsilon &&
        point.latitude <= math.max(a.latitude, b.latitude) + epsilon;
  }

  static bool _pointOnSegment(LatLng point, LatLng start, LatLng end) {
    const epsilon = 1e-10;
    final cross =
        (point.latitude - start.latitude) * (end.longitude - start.longitude) -
        (point.longitude - start.longitude) * (end.latitude - start.latitude);
    if (cross.abs() > epsilon) return false;
    return point.longitude >=
            math.min(start.longitude, end.longitude) - epsilon &&
        point.longitude <= math.max(start.longitude, end.longitude) + epsilon &&
        point.latitude >= math.min(start.latitude, end.latitude) - epsilon &&
        point.latitude <= math.max(start.latitude, end.latitude) + epsilon;
  }
}
