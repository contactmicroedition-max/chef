import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

void main() {
  test(
    'GeoJSON conversion writes longitude before latitude and closes ring',
    () {
      const zone = OrganisationZone(
        points: [LatLng(36.8, 10.1), LatLng(36.81, 10.1), LatLng(36.81, 10.11)],
      );

      final geoJson = zone.toGeoJson();
      final coordinates = geoJson['coordinates']! as List;
      final ring = coordinates.first as List;

      expect(geoJson['type'], 'Polygon');
      expect(ring, [
        [10.1, 36.8],
        [10.1, 36.81],
        [10.11, 36.81],
        [10.1, 36.8],
      ]);
    },
  );

  test('GeoJSON parsing converts lng/lat and removes closing point', () {
    final zone = OrganisationZone.fromGeoJson({
      'type': 'Polygon',
      'coordinates': [
        [
          [10.1, 36.8],
          [10.1, 36.81],
          [10.11, 36.81],
          [10.1, 36.8],
        ],
      ],
    });

    expect(zone.points, const [
      LatLng(36.8, 10.1),
      LatLng(36.81, 10.1),
      LatLng(36.81, 10.11),
    ]);
  });

  test('validation rejects fewer than three points', () {
    const zone = OrganisationZone(points: [LatLng(36.8, 10.1)]);

    expect(zone.isValid, isFalse);
    expect(zone.validationError, contains('at least 3'));
  });

  test('validation rejects self-intersecting polygon', () {
    const zone = OrganisationZone(
      points: [LatLng(0, 0), LatLng(1, 1), LatLng(0, 1), LatLng(1, 0)],
    );

    expect(zone.isValid, isFalse);
    expect(zone.validationError, contains('must not cross'));
  });
}
