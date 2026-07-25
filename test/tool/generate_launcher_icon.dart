// اسکریپت یک‌باره برای تولید آیکون لانچر اپ از روی طرح برداری داخل همین فایل.
// اجرا: flutter test test/tool/generate_launcher_icon.dart
// این فایل بخشی از مجموعه تست‌های خودکار پروژه نیست (به _test.dart ختم نمی‌شود)
// و فقط برای بازتولید آیکون در صورت نیاز نگه داشته شده است.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

const _bgStart = ui.Color(0xFF3E7C6C);
const _bgEnd = ui.Color(0xFF1F3B32);
const _markColor = ui.Color(0xFFFFFCF4);
const _accentColor = ui.Color(0xFFFFB020);

// نقاط علامت تیک و دایره لهجه، به‌صورت نسبتی از اندازه کانواس (مرکز = ۰٫۰)
// و به‌گونه‌ای مقیاس‌شده که کاملاً داخل ناحیه امن آیکون تطبیقی اندروید
// (دایره‌ای به شعاع ~۰٫۳۰۵ اندازه کانواس) بماند.
const _p1 = ui.Offset(-0.1445, 0.017);
const _p2 = ui.Offset(-0.0255, 0.136);
const _p3 = ui.Offset(0.1785, -0.119);
const _strokeFraction = 0.06375;
const _dotCenter = ui.Offset(-0.1445, -0.1445);
const _dotRadiusFraction = 0.0425;

void _paintMark(ui.Canvas canvas, double size, {required double markScale}) {
  final center = ui.Offset(size / 2, size / 2);
  ui.Offset abs(ui.Offset o) =>
      center + ui.Offset(o.dx * markScale * size, o.dy * markScale * size);

  final dotPaint = ui.Paint()
    ..color = _accentColor
    ..style = ui.PaintingStyle.fill
    ..isAntiAlias = true;
  canvas.drawCircle(
    abs(_dotCenter),
    _dotRadiusFraction * markScale * size,
    dotPaint,
  );

  final checkPaint = ui.Paint()
    ..color = _markColor
    ..style = ui.PaintingStyle.stroke
    ..strokeWidth = _strokeFraction * markScale * size
    ..strokeCap = ui.StrokeCap.round
    ..strokeJoin = ui.StrokeJoin.round
    ..isAntiAlias = true;
  final path = ui.Path()
    ..moveTo(abs(_p1).dx, abs(_p1).dy)
    ..lineTo(abs(_p2).dx, abs(_p2).dy)
    ..lineTo(abs(_p3).dx, abs(_p3).dy);
  canvas.drawPath(path, checkPaint);
}

Future<Uint8List> _renderPng(double size, {required bool withBackground}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rect = ui.Rect.fromLTWH(0, 0, size, size);

  if (withBackground) {
    final bgPaint = ui.Paint()
      ..shader = ui.Gradient.linear(
        ui.Offset.zero,
        ui.Offset(size, size),
        [_bgStart, _bgEnd],
      );
    final rrect = ui.RRect.fromRectAndRadius(
      rect,
      ui.Radius.circular(size * 0.22),
    );
    canvas.drawRRect(rrect, bgPaint);
  }

  // بدون پس‌زمینه یعنی لایه foreground آیکون تطبیقی است که باید داخل ناحیه
  // امن دایره‌ای اندروید بماند؛ نسخه‌ی دارای پس‌زمینه محدودیتی ندارد و برای
  // پرشدگی بصری بهتر، کمی بزرگ‌تر رسم می‌شود.
  _paintMark(canvas, size, markScale: withBackground ? 1.3 : 1.0);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.round(), size.round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

Future<void> _writeFile(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generate launcher icon assets', () async {
    const androidRes = 'android/app/src/main/res';

    // آیکون کلاسیک (pre-Android8) برای هر تراکم پیکسلی، شامل پس‌زمینه.
    const legacyDensities = {
      'mipmap-mdpi': 48.0,
      'mipmap-hdpi': 72.0,
      'mipmap-xhdpi': 96.0,
      'mipmap-xxhdpi': 144.0,
      'mipmap-xxxhdpi': 192.0,
    };
    for (final entry in legacyDensities.entries) {
      final bytes = await _renderPng(entry.value, withBackground: true);
      await _writeFile('$androidRes/${entry.key}/ic_launcher.png', bytes);
    }

    // لایه foreground آیکون تطبیقی (Android 8+)، بدون پس‌زمینه، بوم ۱۰۸dp.
    const adaptiveDensities = {
      'mipmap-mdpi': 108.0,
      'mipmap-hdpi': 162.0,
      'mipmap-xhdpi': 216.0,
      'mipmap-xxhdpi': 324.0,
      'mipmap-xxxhdpi': 432.0,
    };
    for (final entry in adaptiveDensities.entries) {
      final bytes = await _renderPng(entry.value, withBackground: false);
      await _writeFile(
        '$androidRes/${entry.key}/ic_launcher_foreground.png',
        bytes,
      );
    }

    // نسخه مرجع با کیفیت بالا برای استفاده در فروشگاه/برندینگ.
    final storeIcon = await _renderPng(1024, withBackground: true);
    await _writeFile('assets/branding/app_icon_1024.png', storeIcon);

    // پیش‌نمایش سریع برای بررسی بصری در اسکرچ‌پد (خارج از ریپازیتوری).
    final preview = await _renderPng(512, withBackground: true);
    await _writeFile(
      r'C:\Users\mehdi\AppData\Local\Temp\claude\c--Users-mehdi-Desktop-Projects-flutter-yadyar\c1c0a562-b1c1-40ac-bb8e-30818c65031e\scratchpad\icon_preview.png',
      preview,
    );

    expect(File('assets/branding/app_icon_1024.png').existsSync(), isTrue);
  });
}
