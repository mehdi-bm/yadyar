import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yadyar_app/screens/support/error_report_screen.dart';
import 'package:yadyar_app/services/ads_api_exception.dart';

import '../support/fake_app_support_gateway.dart';

Widget _wrap(Widget child) => MaterialApp(home: child);

void main() {
  testWidgets('rejects a description shorter than 5 characters', (
    tester,
  ) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(_wrap(ErrorReportScreen(gateway: gateway)));

    await tester.enterText(
      find.byKey(const ValueKey('error_description')),
      'کم',
    );
    await tester.tap(find.byKey(const ValueKey('submit_error_report')));
    await tester.pump();

    expect(gateway.submitCallCount, 0);
    expect(find.textContaining('حداقل'), findsOneWidget);
  });

  testWidgets(
    'submits successfully, clears the field, and shows a success dialog',
    (tester) async {
      final gateway = FakeAppSupportGateway();
      await tester.pumpWidget(_wrap(ErrorReportScreen(gateway: gateway)));

      await tester.enterText(
        find.byKey(const ValueKey('error_description')),
        'یک شرح خطای معتبر',
      );
      await tester.tap(find.byKey(const ValueKey('submit_error_report')));
      await tester.pump();

      expect(gateway.submitCallCount, 1);
      expect(find.text('گزارش شما ثبت شد.'), findsOneWidget);

      await tester.tap(find.text('باشه'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('error_description')),
      );
      expect(field.controller!.text, isEmpty);
    },
  );

  testWidgets('disables the submit button while a request is in flight', (
    tester,
  ) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(_wrap(ErrorReportScreen(gateway: gateway)));
    await tester.enterText(
      find.byKey(const ValueKey('error_description')),
      'یک شرح خطای معتبر',
    );

    await tester.tap(find.byKey(const ValueKey('submit_error_report')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('submit_error_report')),
    );
    expect(button.onPressed, isNull);

    // گفتگوی موفقیت تا لمس «باشه» باز می‌ماند؛ برای پایان تمیز تست آن را ببندیم.
    await tester.pump();
    await tester.tap(find.text('باشه'));
    await tester.pumpAndSettle();
  });

  testWidgets('keeps the entered text and allows retry when submission fails', (
    tester,
  ) async {
    final gateway = FakeAppSupportGateway()
      ..errorToThrow = const AdsApiException(
        'اتصال اینترنت را بررسی و دوباره تلاش کنید.',
      );
    await tester.pumpWidget(_wrap(ErrorReportScreen(gateway: gateway)));

    await tester.enterText(
      find.byKey(const ValueKey('error_description')),
      'یک شرح خطای معتبر',
    );
    await tester.tap(find.byKey(const ValueKey('submit_error_report')));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('اتصال اینترنت را بررسی و دوباره تلاش کنید.'),
      findsOneWidget,
    );
    final field = tester.widget<TextFormField>(
      find.byKey(const ValueKey('error_description')),
    );
    expect(field.controller!.text, 'یک شرح خطای معتبر');

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('submit_error_report')),
    );
    expect(button.onPressed, isNotNull);
  });

  testWidgets(
    'disables submission and shows a clear message when not configured',
    (tester) async {
      final gateway = FakeAppSupportGateway(configured: false);
      await tester.pumpWidget(_wrap(ErrorReportScreen(gateway: gateway)));

      expect(
        find.text('ارسال گزارش خطا در حال حاضر در دسترس نیست.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.byKey(const ValueKey('submit_error_report')),
      );
      expect(button.onPressed, isNull);
    },
  );
}
