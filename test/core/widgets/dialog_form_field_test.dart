import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zone/core/widgets/widgets.dart';

void main() {
  testWidgets('field renders its label and validates required text', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: DialogFormField(controller: controller, label: 'Job title'),
          ),
        ),
      ),
    );

    expect(find.text('Job title'), findsOneWidget);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Required'), findsOneWidget);

    controller.text = 'Cook';
    expect(formKey.currentState!.validate(), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('field respects dark theme and RTL layout', (tester) async {
    final theme = ThemeData.dark();
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: DialogFormField(
              controller: controller,
              label: 'Employee email',
              keyboardType: TextInputType.emailAddress,
            ),
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.keyboardType, TextInputType.emailAddress);
    expect(
      Theme.of(tester.element(find.byType(TextField))).brightness,
      Brightness.dark,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
