import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:zone/features/attendance/presentation/widgets/attendance_location_panel.dart';
import 'package:zone/features/organisations/domain/organisation_zone.dart';

void main() {
  const zone = OrganisationZone(
    points: [
      LatLng(36.8, 10.1),
      LatLng(36.8, 10.2),
      LatLng(36.9, 10.2),
      LatLng(36.9, 10.1),
    ],
  );
  final insidePosition = Position(
    longitude: 10.15,
    latitude: 36.85,
    timestamp: DateTime(2026),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  Widget buildPanel({
    required Position? position,
    required bool isInsideZone,
    bool hasOpenShift = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: AttendanceLocationPanel(
          zone: zone,
          position: position,
          isInsideZone: isInsideZone,
          isLoading: false,
          isRecording: false,
          hasOpenShift: hasOpenShift,
          errorMessage: null,
          onRefreshLocation: () {},
          onRecordShift: (clockIn, currentPosition) async {},
        ),
      ),
    );
  }

  testWidgets('inside zone is green and enables clock-in', (tester) async {
    await tester.pumpWidget(
      buildPanel(position: insidePosition, isInsideZone: true),
    );

    expect(find.text('You are inside the work zone.'), findsOneWidget);
    final polygonLayer = tester.widget<PolygonLayer<Object>>(
      find.byType(PolygonLayer<Object>),
    );
    expect(
      polygonLayer.polygons.single.borderColor,
      ThemeData().colorScheme.primary,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clock in'),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets('outside zone is red and disables clock-in', (tester) async {
    final outsidePosition = Position(
      longitude: 11,
      latitude: 37,
      timestamp: DateTime(2026),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
    await tester.pumpWidget(
      buildPanel(position: outsidePosition, isInsideZone: false),
    );

    expect(
      find.text('You must be inside the work zone to register your presence.'),
      findsOneWidget,
    );
    final polygonLayer = tester.widget<PolygonLayer<Object>>(
      find.byType(PolygonLayer<Object>),
    );
    expect(
      polygonLayer.polygons.single.borderColor,
      ThemeData().colorScheme.error,
    );
    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clock in'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('clock-out remains enabled outside the zone', (tester) async {
    bool? submittedClockIn;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceLocationPanel(
            zone: zone,
            position: null,
            isInsideZone: false,
            isLoading: false,
            isRecording: false,
            hasOpenShift: true,
            errorMessage: null,
            onRefreshLocation: () {},
            onRecordShift: (clockIn, position) async {
              submittedClockIn = clockIn;
            },
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Clock out'),
    );
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('Clock out'));
    await tester.pump();
    expect(submittedClockIn, isFalse);
  });
}
