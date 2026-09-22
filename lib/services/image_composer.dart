import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;

enum TextVPosition { top, center, bottom }
enum TextHAlign { left, center, right }

/// All the text-styling knobs from advertise.html's composer state
/// (textPosition/textBackground/textSize/textAlign/textColor/fontFamily).
/// textColor is now a real Color (picked from the Spectra 6 gradient
/// trough) instead of a fixed auto/white choice.
class TextOverlayOptions {
  final TextVPosition position;
  final bool background;
  final double size;
  final TextHAlign align;
  final Color textColor;
  final String fontFamily;

  const TextOverlayOptions({
    this.position = TextVPosition.center,
    this.background = false,
    this.size = 86,
    this.align = TextHAlign.center,
    this.textColor = const Color(0xFF111111),
    this.fontFamily = 'Inter',
  });

  TextOverlayOptions copyWith({
    TextVPosition? position,
    bool? background,
    double? size,
    TextHAlign? align,
    Color? textColor,
    String? fontFamily,
  }) {
    return TextOverlayOptions(
      position: position ?? this.position,
      background: background ?? this.background,
      size: size ?? this.size,
      align: align ?? this.align,
      textColor: textColor ?? this.textColor,
      fontFamily: fontFamily ?? this.fontFamily,
    );
  }

  /// All 18 fonts from advertise.html's FONT_STACKS, exact Google
  /// Fonts family names — fetched on demand via google_fonts instead
  /// of bundling font files. Now that the picker is a compact wheel
  /// (not a horizontal button row), there's room for the full set.
  static const fontChoices = [
    'Inter',
    'Roboto',
    'Open Sans',
    'Montserrat',
    'Nunito',
    'Rubik',
    'Poppins',
    'Oswald',
    'PT Serif',
    'Playfair Display',
    'Merriweather',
    'Lora',
    'Philosopher',
    'Anton',
    'Bebas Neue',
    'Comfortaa',
    'Caveat',
    'Marck Script',
    'Bad Script',
    'PT Mono',
  ];

  /// The E Ink Spectra 6 panel's 6 real ink primaries — the gradient
  /// trough interpolates across these (not an arbitrary RGB rainbow),
  /// so every colour offered is something the physical display can
  /// actually reproduce (via dithering) rather than a false promise.
  static const spectraStops = [
    Color(0xFF14110F), // black
    Color(0xFF1B5FA8), // blue
    Color(0xFF2E8B57), // green
    Color(0xFFE8C547), // yellow
    Color(0xFFD1443A), // red
    Color(0xFFF5F1E8), // white
  ];

  static Color colorAtT(double t) {
    final stops = spectraStops;
    final n = stops.length - 1;
    final scaled = t.clamp(0.0, 1.0) * n;
    final i = scaled.floor().clamp(0, n - 1);
    final frac = scaled - i;
    return Color.lerp(stops[i], stops[i + 1], frac)!;
  }
}

/// Ported from advertise.html's renderComposition()/wrap() — draws the
/// same 1600x1200 composition (background fill, positioned/scaled
/// photo, auto-shrinking word-wrapped text with an optional background
/// panel and stroke outline) that becomes the actual published image,
/// so the live preview and the final publish are pixel-for-pixel the
/// same drawing code.
class ImageComposer {
  ImageComposer._();

  static const double width = 1600;
  static const double height = 1200;
  static const Color _canvasBg = Color(0xFFE9E6DC);

  static void paint({
    required Canvas canvas,
    ui.Image? photo,
    required String text,
    required TextOverlayOptions options,
    required double imagePositionX,
    required double imagePositionY,
    required double imageScale,
    double imageRotationDeg = 0,
  }) {
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = _canvasBg);

    if (photo != null) {
      final rad = imageRotationDeg * pi / 180;
      final w0 = photo.width.toDouble(), h0 = photo.height.toDouble();
      final cosA = cos(rad).abs(), sinA = sin(rad).abs();
      // Bounding box of the photo once rotated — used instead of the
      // raw width/height so "cover" scaling and the pan limits stay
      // correct at any rotation angle, not just 0°.
      final bboxW = w0 * cosA + h0 * sinA;
      final bboxH = w0 * sinA + h0 * cosA;
      final baseScale = max(width / bboxW, height / bboxH);
      final scale = baseScale * imageScale;
      final dw = w0 * scale, dh = h0 * scale;
      final scaledBboxW = bboxW * scale, scaledBboxH = bboxH * scale;
      final maxShiftX = max(0.0, (scaledBboxW - width) / 2);
      final maxShiftY = max(0.0, (scaledBboxH - height) / 2);
      final shiftX = maxShiftX * imagePositionX;
      final shiftY = maxShiftY * imagePositionY;

      canvas.save();
      canvas.translate(width / 2 + shiftX, height / 2 + shiftY);
      canvas.rotate(rad);
      canvas.drawImageRect(
        photo,
        Rect.fromLTWH(0, 0, w0, h0),
        Rect.fromCenter(center: Offset.zero, width: dw, height: dh),
        Paint(),
      );
      canvas.restore();
    }

    final txt = text.trim();
    if (txt.isEmpty) return;

    const maxTextWidth = width - 300;
    const maxBoxH = height - 140;
    final minFontSize = options.size * 0.6;

    double fontSize = options.size;
    List<String> lines = [];
    double lh = 0, total = 0;
    while (true) {
      lines = _wrap(txt, fontSize, options.fontFamily, maxTextWidth);
      lh = fontSize * 1.14;
      total = lines.length * lh;
      if (total <= maxBoxH || fontSize <= minFontSize) break;
      fontSize -= 4;
    }

    final boxH = max(180.0, min(maxBoxH, total + 70));
    final y = switch (options.position) {
      TextVPosition.top => 65.0,
      TextVPosition.bottom => height - boxH - 65,
      TextVPosition.center => (height - boxH) / 2,
    };

    if (options.background) {
      final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(95, y, width - 190, boxH), const Radius.circular(34));
      canvas.drawRRect(rrect, Paint()..color = const Color(0xE1F5F0E1));
    }

    final resolvedColor = options.textColor;
    final isLight = resolvedColor.computeLuminance() > 0.5;
    final strokeColor = isLight ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.52);
    final textAlign = switch (options.align) {
      TextHAlign.left => TextAlign.left,
      TextHAlign.right => TextAlign.right,
      TextHAlign.center => TextAlign.center,
    };
    final tx = switch (options.align) {
      TextHAlign.left => 135.0,
      TextHAlign.right => width - 135,
      TextHAlign.center => width / 2,
    };

    double ty = y + boxH / 2 - total / 2;
    for (final line in lines) {
      if (!options.background) {
        final strokePainter = TextPainter(
          text: TextSpan(
            text: line,
            style: GoogleFonts.getFont(
              options.fontFamily,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 8
                ..color = strokeColor,
            ),
          ),
          textAlign: textAlign,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: maxTextWidth);
        strokePainter.paint(canvas, Offset(_lineX(tx, options.align, strokePainter.width), ty));
      }
      final fillPainter = TextPainter(
        text: TextSpan(text: line, style: GoogleFonts.getFont(options.fontFamily, fontSize: fontSize, fontWeight: FontWeight.w700, color: resolvedColor)),
        textAlign: textAlign,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);
      fillPainter.paint(canvas, Offset(_lineX(tx, options.align, fillPainter.width), ty));
      ty += lh;
    }
  }

  static double _lineX(double tx, TextHAlign align, double lineWidth) {
    switch (align) {
      case TextHAlign.left:
        return tx;
      case TextHAlign.right:
        return tx - lineWidth;
      case TextHAlign.center:
        return tx - lineWidth / 2;
    }
  }

  static List<String> _wrap(String text, double fontSize, String fontFamily, double maxWidth) {
    final words = text.split(RegExp(r'\s+'));
    final lines = <String>[];
    var line = '';
    for (final word in words) {
      final test = line.isEmpty ? word : '$line $word';
      final w = _measure(test, fontSize, fontFamily);
      if (w > maxWidth && line.isNotEmpty) {
        lines.add(line);
        line = word;
      } else {
        line = test;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  static double _measure(String text, double fontSize, String fontFamily) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: GoogleFonts.getFont(fontFamily, fontSize: fontSize, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    return tp.width;
  }

  /// Renders the composition and encodes it as JPEG at full
  /// 1600x1200 resolution — used for the actual publish. PNG (dart:ui's
  /// only native export format) is lossless and far too large for
  /// photographic content, which was tripping the server's payload-
  /// size limit; JPEG matches what a plain photo publish always used
  /// before this compositor existed.
  static Future<Uint8List> exportJpeg({
    ui.Image? photo,
    required String text,
    required TextOverlayOptions options,
    required double imagePositionX,
    required double imagePositionY,
    required double imageScale,
    double imageRotationDeg = 0,
    int quality = 82,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    paint(
      canvas: canvas,
      photo: photo,
      text: text,
      options: options,
      imagePositionX: imagePositionX,
      imagePositionY: imagePositionY,
      imageScale: imageScale,
      imageRotationDeg: imageRotationDeg,
    );
    final picture = recorder.endRecording();
    final rendered = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await rendered.toByteData(format: ui.ImageByteFormat.rawRgba);
    return compute(_encodeJpegInIsolate, _JpegEncodeArgs(byteData!.buffer.asUint8List(), width.toInt(), height.toInt(), quality));
  }

  static Future<ui.Image> decodeBytes(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}

/// Runs on a background isolate via compute() — encoding a 1600x1200
/// JPEG in pure-Dart (no hardware acceleration) is slow enough that
/// running it on the main isolate froze the whole UI (no animation,
/// nothing responded) for the duration, which looked exactly like a
/// hang even though it was just uninterrupted CPU work.
class _JpegEncodeArgs {
  final Uint8List bytes;
  final int width;
  final int height;
  final int quality;
  const _JpegEncodeArgs(this.bytes, this.width, this.height, this.quality);
}

Uint8List _encodeJpegInIsolate(_JpegEncodeArgs args) {
  final rgbaImage = img.Image.fromBytes(
    width: args.width,
    height: args.height,
    bytes: args.bytes.buffer,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return Uint8List.fromList(img.encodeJpg(rgbaImage, quality: args.quality));
}

/// Live on-screen preview — same drawing code as the final export, via
/// a CustomPainter so what you see while adjusting sliders/text is
/// exactly what gets published.
class CompositionPreviewPainter extends CustomPainter {
  final ui.Image? photo;
  final String text;
  final TextOverlayOptions options;
  final double imagePositionX;
  final double imagePositionY;
  final double imageScale;
  final double imageRotationDeg;

  CompositionPreviewPainter({
    required this.photo,
    required this.text,
    required this.options,
    required this.imagePositionX,
    required this.imagePositionY,
    required this.imageScale,
    this.imageRotationDeg = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / ImageComposer.width, size.height / ImageComposer.height);
    ImageComposer.paint(
      canvas: canvas,
      photo: photo,
      text: text,
      options: options,
      imagePositionX: imagePositionX,
      imagePositionY: imagePositionY,
      imageScale: imageScale,
      imageRotationDeg: imageRotationDeg,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CompositionPreviewPainter oldDelegate) {
    return oldDelegate.photo != photo ||
        oldDelegate.text != text ||
        oldDelegate.options != options ||
        oldDelegate.imagePositionX != imagePositionX ||
        oldDelegate.imagePositionY != imagePositionY ||
        oldDelegate.imageScale != imageScale ||
        oldDelegate.imageRotationDeg != imageRotationDeg;
  }
}
