// Genereert het app-icoon (stopwatch op geel verloop): dart run tool/make_icon.dart
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

void main() {
  const s = 1024;
  final im = img.Image(width: s, height: s, numChannels: 4);
  final black = img.ColorRgba8(18, 18, 22, 255);
  for (var y = 0; y < s; y++) {
    for (var x = 0; x < s; x++) {
      final t = (x + y) / (2 * s);
      im.setPixelRgba(x, y, 255, (214 - 46 * t).round(), (31 - 31 * t).round(), 255);
    }
  }
  const cx = 512, cy = 560;
  img.fillCircle(im, x: cx, y: cy, radius: 300, color: black);
  img.fillCircle(im, x: cx, y: cy, radius: 236, color: img.ColorRgba8(255, 200, 20, 255));
  img.fillCircle(im, x: cx, y: cy, radius: 206, color: black);
  img.fillRect(im, x1: 452, y1: 170, x2: 572, y2: 240, color: black, radius: 20);
  img.fillRect(im, x1: 492, y1: 230, x2: 532, y2: 280, color: black);
  // Wijzer
  final yellow = img.ColorRgba8(255, 214, 31, 255);
  for (var r = 0; r < 170; r++) {
    final a = -pi / 2 + pi / 3;
    img.fillCircle(im,
        x: (cx + r * cos(a)).round(), y: (cy + r * sin(a)).round(), radius: 20, color: yellow);
  }
  img.fillCircle(im, x: cx, y: cy, radius: 36, color: yellow);

  const sizes = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192};
  sizes.forEach((dpi, px) {
    final out = img.copyResize(im, width: px, height: px, interpolation: img.Interpolation.average);
    File('android/app/src/main/res/mipmap-$dpi/ic_launcher.png').writeAsBytesSync(img.encodePng(out));
  });
  File('tool/icon.png').writeAsBytesSync(img.encodePng(img.copyResize(im, width: 256, height: 256)));
}
