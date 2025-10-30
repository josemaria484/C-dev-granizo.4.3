import 'dart:typed_data';

import 'package:flutter_map/flutter_map.dart'; // LatLngBounds
import 'package:latlong2/latlong.dart';        // LatLng

/// Modelo que encapsula un overlay PNG con transparencia listo para el mapa.
class CloudOverlay {
  final Uint8List imageBytes;
  final LatLngBounds bounds;
  final DateTime generatedAt;
  final List<LatLng> points;

  CloudOverlay({
    required this.imageBytes,
    required this.bounds,
    DateTime? generatedAt,
    List<LatLng>? points,
  })  : generatedAt = generatedAt ?? DateTime.now(),
        points = points ?? const [];

  int get sizeInBytes => imageBytes.lengthInBytes;

  bool get hasPixels => imageBytes.isNotEmpty;
}
