import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart'; // LatLngBounds
import 'package:image/image.dart' as img;
import 'package:latlong2/latlong.dart';

import '../core/ai/color_mapper.dart';
import '../data/models/cloud_overlay.dart';
import '../utils/logger.dart';

/// Servicio encargado de generar un PNG con transparencia a partir del radar DACC.
class CloudOverlayService {
  static final LatLngBounds _defaultBounds = LatLngBounds(
    const LatLng(-35.5, -69.5), // southWest
    const LatLng(-33.5, -67.5), // northEast
  );

  static LatLngBounds get defaultBounds => _defaultBounds;

  /// Construye un overlay PNG con canales alfa utilizando el mapa sintético.
  static Future<CloudOverlay?> buildOverlay(img.Image radarImage, {int minDbz = 20}) async {
    return Future<CloudOverlay?>(() {
      try {
        final width = radarImage.width;
        final height = radarImage.height;
        final overlay = img.Image(width, height);
        var hasContent = false;

        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            final pixel = radarImage.getPixel(x, y);
            final r = img.getRed(pixel);
            final g = img.getGreen(pixel);
            final b = img.getBlue(pixel);

            final dbz = ColorMapper.estimateDBZ(r, g, b);
            if (ColorMapper.isSignificant(dbz, minThreshold: minDbz)) {
              final opacity = _alphaForDbz(dbz);
              final color = ColorMapper.getSyntheticColor(dbz, opacity: opacity);
              overlay.setPixelRgba(x, y, color.red, color.green, color.blue, color.alpha);
              hasContent = true;
            } else {
              overlay.setPixelRgba(x, y, 0, 0, 0, 0);
            }
          }
        }

        if (!hasContent) {
          AppLogger.info('Overlay sin datos relevantes, se omite generación de PNG.');
          return null;
        }

        final pngBytes = Uint8List.fromList(img.encodePng(overlay, level: 0));
        AppLogger.success('Overlay de nubes generado (${pngBytes.length} bytes).');
        return CloudOverlay(imageBytes: pngBytes, bounds: _defaultBounds);
      } catch (e, st) {
        AppLogger.error('Error generando overlay de nubes', e, st);
        return null;
      }
    });
  }

  static double _alphaForDbz(int dbz) {
    if (dbz >= 65) return 0.95;
    if (dbz >= 55) return 0.88;
    if (dbz >= 45) return 0.78;
    if (dbz >= 35) return 0.66;
    if (dbz >= 25) return 0.5;
    return 0.4;
  }
}
