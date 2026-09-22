import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

class AppIconTarget {
  final String fileName;
  final int size;

  AppIconTarget({required this.fileName, required this.size});
}

class AppIconGenerator {
  static const androidMipmapSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  static const webFaviconSize = 16;
  static const webIconSizes = {192, 512};

  static const maskableSafeZoneRatio = 0.8;

  img.Image? decode(Uint8List sourceBytes) {
    try {
      return img.decodeImage(sourceBytes);
    } catch (_) {
      return null;
    }
  }

  Uint8List resizeToPng(img.Image source, int size) {
    final resized = img.copyResize(
      source,
      width: size,
      height: size,
      interpolation: img.Interpolation.average,
    );
    return Uint8List.fromList(img.encodePng(resized));
  }

  Uint8List resizeToMaskablePng(img.Image source, int size) {
    final innerSize = (size * maskableSafeZoneRatio).round();
    final inner = img.copyResize(
      source,
      width: innerSize,
      height: innerSize,
      interpolation: img.Interpolation.average,
    );
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    final offset = ((size - innerSize) / 2).round();
    img.compositeImage(canvas, inner, dstX: offset, dstY: offset);
    return Uint8List.fromList(img.encodePng(canvas));
  }

  bool hasVisibleTransparency(img.Image source) {
    if (!source.hasAlpha) return false;
    for (final pixel in source) {
      if (pixel.aNormalized < 1.0) return true;
    }
    return false;
  }

  List<AppIconTarget> parseAppIconSetTargets(String contentsJson) {
    final decoded = jsonDecode(contentsJson) as Map<String, dynamic>;
    final images = decoded['images'] as List;
    final targets = <String, int>{};

    for (final entry in images) {
      final map = Map<String, dynamic>.from(entry as Map);
      final fileName = map['filename'] as String?;
      if (fileName == null) continue;

      final baseSize = double.parse((map['size'] as String).split('x').first);
      final scale = double.parse((map['scale'] as String).replaceAll('x', ''));
      targets[fileName] = (baseSize * scale).round();
    }

    return targets.entries
        .map((e) => AppIconTarget(fileName: e.key, size: e.value))
        .toList();
  }
}
