// Paints Khanak's launcher icons, splash images and store icon from the same
// LogoPainter the app uses, so they always match. Run after changing the logo:
//
//   fvm flutter test tool/brand_assets_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khanak/components/appLogo.dart';

const _res = 'android/app/src/main/res';

/// Android densities and their scale from mdpi.
const _densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

Future<void> _write(String path, int pixels, LogoPainter painter, {Color? background}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final size = Size.square(pixels.toDouble());
  if (background != null) canvas.drawRect(Offset.zero & size, Paint()..color = background);
  painter.paint(canvas, size);
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File(path)..createSync(recursive: true);
  file.writeAsBytesSync(png!.buffer.asUint8List());
}

void main() {
  test('brand assets', () async {
    for (final MapEntry(key: density, value: scale) in _densities.entries) {
      // Launchers before Android 8 show the icon as it is: the rounded tile.
      await _write('$_res/mipmap-$density/ic_launcher.png', (48 * scale).round(), const LogoPainter());

      // Android 8 and later mask an adaptive icon themselves: a square back
      // layer, and the arch kept inside the 66dp safe circle.
      final layer = (108 * scale).round();
      await _write(
        '$_res/mipmap-$density/ic_launcher_background.png',
        layer,
        const LogoPainter(layer: LogoLayer.background, rounded: false),
      );
      await _write(
        '$_res/mipmap-$density/ic_launcher_foreground.png',
        layer,
        const LogoPainter(layer: LogoLayer.foreground, contentScale: 0.72),
      );
      await _write(
        '$_res/mipmap-$density/ic_launcher_monochrome.png',
        layer,
        const LogoPainter(layer: LogoLayer.monochrome, contentScale: 0.72),
      );
    }

    // The arch on its own for the splash screens: 288dp, the size Android 12
    // gives a splash icon without a background, the arch about 130dp wide
    // inside its 192dp circle. The app's own splash draws it the same size.
    await _write(
      '$_res/drawable-xxxhdpi/splash_logo.png',
      1152,
      const LogoPainter(layer: LogoLayer.foreground, contentScale: 0.825),
    );

    // Play Store: 512 × 512, square; the store rounds the corners itself.
    await _write('store/play_icon_512.png', 512, const LogoPainter(rounded: false));
  });
}
