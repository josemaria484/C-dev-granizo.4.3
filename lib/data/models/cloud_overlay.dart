import 'dart:typed_data';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Overlay PNG con transparencia listo para el mapa.
class CloudOverlay {
  final Uint8List imageBytes;
  final LatLngBounds bounds;
  final DateTime generatedAt;
  final List<LatLng> points;

  const CloudOverlay({
    required this.imageBytes,
    required this.bounds,
    DateTime? generatedAt,
    this.points = const [],
  }) : generatedAt = generatedAt ?? const DateTime.fromMillisecondsSinceEpoch(0);

  bool get hasPixels => imageBytes.isNotEmpty;
}
