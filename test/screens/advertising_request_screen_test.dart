import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yadyar_app/screens/support/advertising_request_screen.dart';

import '../support/fake_app_support_gateway.dart';

Widget _wrap(Widget child, {Size size = const Size(400, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(home: child),
);

Future<void> _fillValidForm(
  WidgetTester tester, {
  String phone = '09123456789',
}) async {
  await tester.enterText(
    find.byKey(const ValueKey('advertising_full_name')),
    'علی رضایی',
  );
  await tester.enterText(
    find.byKey(const ValueKey('advertising_phone')),
    phone,
  );
  await tester.enterText(
    find.byKey(const ValueKey('advertising_province')),
    'تهران',
  );
  await tester.enterText(
    find.byKey(const ValueKey('advertising_city')),
    'تهران',
  );
}

void main() {
  testWidgets('validates all required fields', (tester) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(_wrap(AdvertisingRequestScreen(gateway: gateway)));

    await tester.tap(find.byKey(const ValueKey('submit_advertising_request')));
    await tester.pump();

    expect(gateway.submitCallCount, 0);
    expect(find.text('نام و نام خانوادگی را وارد کنید.'), findsOneWidget);
    expect(find.text('شماره تماس را وارد کنید.'), findsOneWidget);
    expect(find.text('استان را وارد کنید.'), findsOneWidget);
    expect(find.text('شهر را وارد کنید.'), findsOneWidget);
  });

  testWidgets(
    'accepts Persian-digit phone numbers and normalizes them for submission',
    (tester) async {
      final gateway = FakeAppSupportGateway();
      await tester.pumpWidget(
        _wrap(AdvertisingRequestScreen(gateway: gateway)),
      );

      await _fillValidForm(tester, phone: '۰۹۱۲۳۴۵۶۷۸۹');
      await tester.tap(
        find.byKey(const ValueKey('submit_advertising_request')),
      );
      await tester.pump();

      expect(gateway.submitCallCount, 1);
      expect(gateway.lastAdvertisingRequest!['phoneNumber'], '09123456789');
    },
  );

  testWidgets('submits full payload and clears fields only on success', (
    tester,
  ) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(_wrap(AdvertisingRequestScreen(gateway: gateway)));

    await _fillValidForm(tester);
    await tester.enterText(
      find.byKey(const ValueKey('advertising_details')),
      'یک توضیح',
    );
    await tester.tap(find.byKey(const ValueKey('submit_advertising_request')));
    await tester.pump();

    expect(gateway.lastAdvertisingRequest, {
      'fullName': 'علی رضایی',
      'phoneNumber': '09123456789',
      'province': 'تهران',
      'city': 'تهران',
      'details': 'یک توضیح',
    });

    await tester.tap(find.text('باشه'));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextFormField>(
      find.byKey(const ValueKey('advertising_full_name')),
    );
    expect(nameField.controller!.text, isEmpty);
  });

  testWidgets('disables the submit button while in flight', (tester) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(_wrap(AdvertisingRequestScreen(gateway: gateway)));
    await _fillValidForm(tester);

    await tester.tap(find.byKey(const ValueKey('submit_advertising_request')));
    await tester.pump();

    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('submit_advertising_request')),
    );
    expect(button.onPressed, isNull);

    // گفتگوی موفقیت تا لمس «باشه» باز می‌ماند؛ برای پایان تمیز تست آن را ببندیم.
    await tester.pump();
    await tester.tap(find.text('باشه'));
    await tester.pumpAndSettle();
  });

  testWidgets('lays out without overflow on a narrow screen', (tester) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(
      _wrap(
        AdvertisingRequestScreen(gateway: gateway),
        size: const Size(320, 640),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('lays out without overflow on a wide screen', (tester) async {
    final gateway = FakeAppSupportGateway();
    await tester.pumpWidget(
      _wrap(
        AdvertisingRequestScreen(gateway: gateway),
        size: const Size(1024, 800),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
