import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/features/organisations/presentation/controllers/organisation_zone_controller.dart';
import 'package:zone/features/organisations/presentation/widgets/organisation_zone_map.dart';

void main() {
  testWidgets('map shows an icon at the located current position', (
    tester,
  ) async {
    final mapController = MapController();
    final zoneController = OrganisationZoneController();
    const currentPosition = LatLng(36.8, 10.18);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 400,
            child: OrganisationZoneMap(
              mapController: mapController,
              zoneController: zoneController,
              isDrawing: false,
              onMapReady: () {},
              currentPosition: currentPosition,
            ),
          ),
        ),
      ),
    );

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers, hasLength(1));
    expect(markerLayer.markers.single.point, currentPosition);
    expect(find.byIcon(Icons.my_location_rounded), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    zoneController.dispose();
    mapController.dispose();
  });
}
