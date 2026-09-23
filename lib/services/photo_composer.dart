import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../theme.dart';

/// Maakt een kopie van de foto met onderin een balk met de naam erop.
/// Geeft het pad van het nieuwe JPG-bestand terug.
Future<String> composePhotoWithName(String sourcePath, String name) async {
  const maxSide = 1600;
  final bytes = await File(sourcePath).readAsBytes();

  // Eerst de afmetingen bepalen om de schaal te kiezen.
  final probe = await ui.instantiateImageCodec(bytes);
  final probeFrame = await probe.getNextFrame();
  final w0 = probeFrame.image.width, h0 = probeFrame.image.height;
  probeFrame.image.dispose();
  final scale = (maxSide / (w0 > h0 ? w0 : h0)).clamp(0.0, 1.0);

  final codec = await ui.instantiateImageCodec(
    bytes,
    targetWidth: (w0 * scale).round(),
    targetHeight: (h0 * scale).round(),
  );
  final photo = (await codec.getNextFrame()).image;
  final w = photo.width.toDouble(), h = photo.height.toDouble();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawImage(photo, Offset.zero, Paint());

  // Balk onderin.
  final fontSize = (w < h ? w : h) * 0.065;
  final barH = fontSize * 2.4;
  final barRect = Rect.fromLTWH(0, h - barH, w, barH);
  canvas.drawRect(
    barRect,
    Paint()
      ..shader = ui.Gradient.linear(
        barRect.topCenter,
        barRect.bottomCenter,
        [const Color(0xE6141418), const Color(0xF20B0B0D)],
      ),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h - barH, w, fontSize * 0.14),
    Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h - barH),
        Offset(w, h - barH),
        [AppColors.yellow, AppColors.amber],
      ),
  );
  final tp = TextPainter(
    text: TextSpan(
      text: name,
      style: TextStyle(
        color: AppColors.yellow,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: w - fontSize);
  tp.paint(
    canvas,
    Offset((w - tp.width) / 2, h - barH + (barH - tp.height) / 2 + fontSize * 0.07),
  );

  final out = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final rgba = await out.toByteData(format: ui.ImageByteFormat.rawRgba);
  photo.dispose();
  out.dispose();

  final jpg = await compute(_encodeJpg, _Raw(rgba!.buffer.asUint8List(), w.toInt(), h.toInt()));

  final dir = await getTemporaryDirectory();
  final safe = name.replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_');
  final file = File(
      '${dir.path}/foto_${safe}_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await file.writeAsBytes(jpg, flush: true);
  return file.path;
}

class _Raw {
  _Raw(this.bytes, this.width, this.height);
  final Uint8List bytes;
  final int width;
  final int height;
}

Uint8List _encodeJpg(_Raw r) {
  final image = img.Image.fromBytes(
    width: r.width,
    height: r.height,
    bytes: r.bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: 86);
}
