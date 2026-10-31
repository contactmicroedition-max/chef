import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/features/organisations/domain/organisation_draft.dart';
import 'package:zone/features/organisations/presentation/screens/organisation_zone_screen.dart';

void main() {
  Widget buildScreen() {
    return const ProviderScope(
      child: MaterialApp(
        home: OrganisationZoneScreen(
          draft: OrganisationDraft(
            name: 'Test organisation',
            currency: 'TND',
            timezone: 'Africa/Tunis',
          ),
        ),
      ),
    );
  }

  testWidgets('save stays disabled until the polygon is valid', (tester) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));

    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create organisation'),
    );
    expect(saveButton.onPressed, isNull);
  });

  testWidgets('one polygon is drawn; undo and clear update its vertices', (
    tester,
  ) async {
    await tester.pumpWidget(buildScreen());
    await tester.pump(const Duration(milliseconds: 300));
    final mapRect = tester.getRect(find.byType(FlutterMap));
    final center = mapRect.center;

    await tester.tapAt(center + const Offset(-30, -30));
    await tester.pump();
    await tester.tapAt(center + const Offset(30, -30));
    await tester.pump();
    await tester.tapAt(center + const Offset(30, 30));
    await tester.pump();
    await tester.tapAt(center + const Offset(-30, 30));
    await tester.pump();

    expect(find.byType(PolygonLayer), findsOneWidget);
    final saveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create organisation'),
    );
    expect(saveButton.onPressed, isNotNull);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(find.byType(PolygonLayer), findsOneWidget);

    await tester.tap(find.text('Clear'));
    await tester.pump();
    expect(find.byType(PolygonLayer), findsNothing);
    final disabledSaveButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Create organisation'),
    );
    expect(disabledSaveButton.onPressed, isNull);
  });
}
