import 'package:flutter/material.dart';

/// لوگوی برداری اپ (همان ترکیب رنگ و طرح آیکون لانچر) برای استفاده در
/// اسپلش‌اسکرین و هر جای دیگری که نیاز به نمایش برند باشد.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _AppLogoPainter()),
    );
  }
}

class _AppLogoPainter extends CustomPainter {
  static const _bgStart = Color(0xFF3E7C6C);
  static const _bgEnd = Color(0xFF1F3B32);
  static const _markColor = Color(0xFFFFFCF4);
  static const _accentColor = Color(0xFFFFB020);

  // همان نسبت‌های استفاده‌شده در تولید آیکون لانچر
  // (test/tool/generate_launcher_icon.dart) برای یکسان بودن برند.
  static const _p1 = Offset(-0.1445, 0.017);
  static const _p2 = Offset(-0.0255, 0.136);
  static const _p3 = Offset(0.1785, -0.119);
  static const _strokeFraction = 0.06375;
  static const _dotCenter = Offset(-0.1445, -0.1445);
  static const _dotRadiusFraction = 0.0425;
  static const _markScale = 1.3;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_bgStart, _bgEnd],
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(side * 0.22)),
      bgPaint,
    );

    final center = rect.center;
    Offset abs(Offset o) =>
        center + Offset(o.dx * _markScale * side, o.dy * _markScale * side);

    final dotPaint = Paint()
      ..color = _accentColor
      ..isAntiAlias = true;
    canvas.drawCircle(
      abs(_dotCenter),
      _dotRadiusFraction * _markScale * side,
      dotPaint,
    );

    final checkPaint = Paint()
      ..color = _markColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeFraction * _markScale * side
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final path = Path()
      ..moveTo(abs(_p1).dx, abs(_p1).dy)
      ..lineTo(abs(_p2).dx, abs(_p2).dy)
      ..lineTo(abs(_p3).dx, abs(_p3).dy);
    canvas.drawPath(path, checkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
