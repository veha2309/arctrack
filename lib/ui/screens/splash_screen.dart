import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
              gradient: RadialGradient(
                  center: Alignment(0, -.25),
                  radius: .85,
                  colors: [ArcColors.raised, ArcColors.background])),
          child: SafeArea(
              child: SizedBox.expand(
                  child: Column(children: [
            const Spacer(flex: 3),
            Semantics(
                label: 'ArcTrack logo',
                child: const SizedBox(
                    width: 144,
                    height: 144,
                    child: CustomPaint(painter: ArcMarkPainter()))),
            const SizedBox(height: 28),
            const Text('ARCTRACK',
                style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4)),
            const SizedBox(height: 10),
            const Text('Build your momentum.',
                style: TextStyle(color: ArcColors.muted, fontSize: 16)),
            const Spacer(flex: 2),
            const SizedBox(
                width: 72, child: LinearProgressIndicator(minHeight: 3)),
            const SizedBox(height: 36),
            const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.offline_bolt_outlined,
                  size: 16, color: ArcColors.accent),
              SizedBox(width: 8),
              Text('OFFLINE BY DESIGN',
                  style: TextStyle(
                      color: ArcColors.muted,
                      fontSize: 10,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700))
            ]),
            const SizedBox(height: 36),
          ]))),
        ),
      );
}

class ArcMarkPainter extends CustomPainter {
  const ArcMarkPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 144;
    canvas.scale(scale);
    canvas.drawCircle(
        const Offset(72, 72),
        64,
        Paint()
          ..color = ArcColors.line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    canvas.drawArc(
        const Rect.fromLTWH(8, 8, 128, 128),
        -math.pi * .9,
        math.pi * 1.5,
        false,
        Paint()
          ..color = ArcColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round);
    final mark = Path()
      ..moveTo(38, 104)
      ..lineTo(64, 40)
      ..lineTo(79, 40)
      ..lineTo(106, 104)
      ..lineTo(91, 104)
      ..lineTo(85, 88)
      ..lineTo(58, 88)
      ..lineTo(52, 104)
      ..close();
    final cutout = Path()
      ..moveTo(63, 74)
      ..lineTo(79, 74)
      ..lineTo(71, 54)
      ..close();
    canvas.drawPath(Path.combine(PathOperation.difference, mark, cutout),
        Paint()..color = ArcColors.accent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
