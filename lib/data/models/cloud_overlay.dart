import 'dart:typed_data';
import 'package:latlong2/latlong.dart';

/// Modelo que encapsula un overlay PNG con transparencia listo para el mapa.
class CloudOverlay {
  final Uint8List imageBytes;
  final LatLngBounds bounds;
  final DateTime generatedAt;

  CloudOverlay({
    required this.imageBytes,
    required this.bounds,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  int get sizeInBytes => imageBytes.lengthInBytes;

  bool get hasPixels => imageBytes.isNotEmpty;
}
