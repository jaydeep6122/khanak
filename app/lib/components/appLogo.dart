import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Which part of the logo to paint. The launcher icons, the splash screens
/// and the logo inside the app are all painted from here, so they match.
enum LogoLayer {
  /// The dark tile and the kiln arch: the app icon as people see it.
  full,

  /// The dark tile only (an adaptive icon's back layer).
  background,

  /// The kiln arch only, on nothing (an adaptive icon's front layer, the
  /// splash screens).
  foreground,

  /// The arch in one flat colour, for Android's themed icons.
  monochrome,
}

/// Colours of the logo, fixed in light and dark alike.
abstract final class LogoColors {
  /// Behind the splash screens.
  static const splash = Color(0xFF14110E);
  static const tile = Color(0xFF1C1915);
  static const ember = Color(0xFF6A2E17);
  static const brickLight = Color(0xFFF29266);
  static const brick = Color(0xFFC64A1E);
}

/// Khanak's logo: the mouth of a brick kiln, an arch of five bricks over a
/// glowing fire, standing on two courses of bricks, on a dark tile with a
/// warm glow in the corner.
///
/// Drawn on a 108 × 108 grid (Android's adaptive icon canvas). [contentScale]
/// shrinks the arch about the centre: adaptive icons and splash screens need
/// it inside a safe circle.
class LogoPainter extends CustomPainter {
  final LogoLayer layer;
  final double contentScale;

  /// Round the tile's corners; off for layers the launcher masks itself.
  final bool rounded;
  final Color monochromeColor;

  const LogoPainter({
    this.layer = LogoLayer.full,
    this.contentScale = 0.9,
    this.rounded = true,
    this.monochromeColor = Colors.white,
  });

  // Where the arch and its base sit on the grid; its middle goes to the
  // centre of the canvas.
  static const _contentCenter = Offset(54, 59.35);
  static const _archCenter = Offset(54, 64);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / 108);
    if (layer == LogoLayer.full || layer == LogoLayer.background) _paintTile(canvas);
    if (layer != LogoLayer.background) {
      canvas.save();
      canvas.translate(54, 54);
      canvas.scale(contentScale);
      canvas.translate(-_contentCenter.dx, -_contentCenter.dy);
      _paintKiln(canvas);
      canvas.restore();
    }
    canvas.restore();
  }

  void _paintTile(Canvas canvas) {
    const rect = Rect.fromLTWH(0, 0, 108, 108);
    final paint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(0.56, -0.76),
        radius: 0.9,
        colors: [LogoColors.ember, Color(0xFF2A1E17), LogoColors.tile],
        stops: [0, 0.55, 1],
      ).createShader(rect);
    if (rounded) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(26)), paint);
    } else {
      canvas.drawRect(rect, paint);
    }
  }

  void _paintKiln(Canvas canvas) {
    final mono = layer == LogoLayer.monochrome;

    // The fire in the kiln's mouth.
    final fire = Path()
      ..moveTo(41, 64)
      ..arcToPoint(const Offset(67, 64), radius: const Radius.circular(13))
      ..lineTo(67, 70)
      ..lineTo(41, 70)
      ..close();
    canvas.drawPath(
      fire,
      mono
          ? (Paint()..color = monochromeColor.withValues(alpha: 0.55))
          : (Paint()
              ..shader = RadialGradient(
                center: const Alignment(0, 1),
                radius: 0.9,
                colors: const [Color(0xFFFFE3A3), Color(0xFFFFA24C), Color(0xFFE0552A)],
                stops: const [0, 0.45, 1],
              ).createShader(fire.getBounds())),
    );

    // Each brick catches the light on its upper left.
    void brick(Path path) {
      canvas.drawPath(
        path,
        mono
            ? (Paint()..color = monochromeColor)
            : (Paint()
                ..shader = const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [LogoColors.brickLight, LogoColors.brick],
                ).createShader(path.getBounds())),
      );
    }

    // The arch: five bricks round a half circle, a thin joint between them.
    const inner = 15.0, outer = 30.0, count = 5, joint = 3.2;
    for (var i = 0; i < count; i++) {
      final from = 180 - i * 180 / count - (i > 0 ? joint / 2 : 0);
      final to = 180 - (i + 1) * 180 / count + (i < count - 1 ? joint / 2 : 0);
      final start = -from * math.pi / 180;
      final sweep = (from - to) * math.pi / 180;
      brick(
        Path()
          ..arcTo(Rect.fromCircle(center: _archCenter, radius: outer), start, sweep, true)
          ..arcTo(Rect.fromCircle(center: _archCenter, radius: inner), start + sweep, -sweep, false)
          ..close(),
      );
    }

    // Two courses of bricks under it, the fire between the lower ones.
    RRect block(double x, double y, double w) =>
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, 7), const Radius.circular(1.6));
    for (final rect in [block(24, 67, 14), block(70, 67, 14), block(24, 76.5, 28.5), block(55.5, 76.5, 28.5)]) {
      brick(Path()..addRRect(rect));
    }
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.layer != layer ||
      old.contentScale != contentScale ||
      old.rounded != rounded ||
      old.monochromeColor != monochromeColor;
}

/// The app icon as a widget: the kiln on its dark tile.
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 56});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 26 / 108),
        boxShadow: [
          BoxShadow(
            color: LogoColors.tile.withValues(alpha: 0.4),
            blurRadius: size * 0.35,
            spreadRadius: -size * 0.12,
            offset: Offset(0, size * 0.14),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: size,
        child: const CustomPaint(painter: LogoPainter()),
      ),
    );
  }
}
