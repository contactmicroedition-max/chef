import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/core/widgets/paginated_list.dart';

void main() {
  testWidgets('shows ten items per page and navigates between pages', (
    tester,
  ) async {
    final items = List.generate(11, (index) => 'record-$index');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PaginatedList<String>(
            items: items,
            itemBuilder: (context, item, index) => Text(item),
          ),
        ),
      ),
    );

    expect(find.text('1–10 of 11'), findsOneWidget);
    expect(find.text('record-0'), findsOneWidget);
    expect(find.text('record-9'), findsOneWidget);
    expect(find.text('record-10'), findsNothing);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();

    expect(find.text('11–11 of 11'), findsOneWidget);
    expect(find.text('record-10'), findsOneWidget);
    expect(find.text('record-0'), findsNothing);

    await tester.tap(find.byTooltip('Previous page'));
    await tester.pumpAndSettle();

    expect(find.text('1–10 of 11'), findsOneWidget);
    expect(find.text('record-0'), findsOneWidget);
  });
}
