import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image/image.dart' as img;
import '../data/models/cloud_overlay.dart';

/// Servicio mínimo para construir el overlay desde una imagen procesada.
class CloudOverlayService {
  static final LatLngBounds _defaultBounds = LatLngBounds(
    const LatLng(-35.5, -69.5),
    const LatLng(-33.5, -67.5),
  );

  static LatLngBounds get defaultBounds => _defaultBounds;

  static Future<CloudOverlay> buildOverlay({
    required img.Image image,
    LatLngBounds? bounds,
    List<LatLng> points = const [],
    DateTime? generatedAt,
  }) async {
    final Uint8List png = Uint8List.fromList(img.encodePng(image));
    return CloudOverlay(
      imageBytes: png,
      bounds: bounds ?? _defaultBounds,
      generatedAt: generatedAt ?? DateTime.now(),
      points: points,
    );
  }
}
