import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/core/widgets/app_button.dart';

void main() {
  testWidgets('primary button invokes its callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            onPressed: () => tapped = true,
            child: const Text('Save'),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(FilledButton));
    expect(tapped, isTrue);
  });

  testWidgets('loading button shows progress and disables its callback', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppButton(
            onPressed: () => tapped = true,
            isLoading: true,
            child: const Text('Save'),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(FilledButton),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byType(FilledButton));
    expect(tapped, isFalse);
  });

  testWidgets('button variants use themed controls in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const Scaffold(
          body: Column(
            children: [
              AppButton(
                onPressed: null,
                variant: AppButtonVariant.secondary,
                child: Text('Secondary'),
              ),
              AppButton(
                onPressed: null,
                variant: AppButtonVariant.text,
                child: Text('Text'),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(OutlinedButton), findsOneWidget);
    expect(find.byType(TextButton), findsOneWidget);
  });
}
