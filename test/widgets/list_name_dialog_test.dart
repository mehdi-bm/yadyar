import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yadyar_app/screens/shopping/widgets/shopping_list_actions.dart';
import 'package:yadyar_app/screens/shopping/widgets/shopping_visuals.dart';

void main() {
  /// دیالوگ را باز می‌کند و تابعی برمی‌گرداند که نتیجه pop شده را می‌دهد.
  Future<ListFormResult? Function()> openDialog(
    WidgetTester tester, {
    String initialName = '',
    int? initialColorValue,
  }) async {
    ListFormResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showListFormDialog(
                  context,
                  title: 'لیست جدید',
                  initialName: initialName,
                  initialColorValue: initialColorValue,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return () => result;
  }

  // رگرسیون: dispose زودهنگام کنترلر (پیش از پایان انیمیشن خروج دیالوگ)
  // روی گوشی خطای `_dependents.isEmpty` می‌داد.
  testWidgets('saving a name closes the dialog cleanly and returns it', (
    tester,
  ) async {
    final readResult = await openDialog(tester);

    await tester.enterText(find.byType(TextFormField), '  خرید هفتگی  ');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(readResult()!.name, 'خرید هفتگی');
    expect(readResult()!.colorValue, isNull);
  });

  testWidgets('picking a color returns it with the name', (tester) async {
    final readResult = await openDialog(tester, initialName: 'میوه');

    // اولین نمونه رنگ «رنگ پیش‌فرض» است؛ دومی اولین رنگ پالت.
    await tester.tap(find.bySemanticsLabel('رنگ').first);
    await tester.pump();
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(readResult()!.name, 'میوه');
    expect(readResult()!.colorValue, shoppingPalette.first);
  });

  testWidgets('empty name shows validation error and keeps dialog open', (
    tester,
  ) async {
    await openDialog(tester);

    await tester.tap(find.text('ذخیره'));
    await tester.pump();

    expect(find.text('نام نمی‌تواند خالی باشد'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('cancel closes the dialog and returns null', (tester) async {
    final readResult = await openDialog(tester);

    await tester.tap(find.text('انصراف'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
    expect(readResult(), isNull);
  });
}
