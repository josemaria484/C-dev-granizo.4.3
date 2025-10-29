// lib/data/models/radar_data.dart

import 'dart:typed_data';

/// Modelo de datos del radar DACC
class RadarData {
  /// Imagen PNG del radar (bytes)
  final Uint8List imageBytes;

  /// Timestamp de cuando se descargó
  final DateTime downloadedAt;

  /// Timestamp de la imagen según el DACC (si está disponible)
  final DateTime? radarTimestamp;

  /// URL de origen
  final String sourceUrl;

  /// Tamaño de la imagen en bytes
  int get sizeInBytes => imageBytes.length;

  /// Tamaño legible (KB, MB)
  String get sizeFormatted {
    if (sizeInBytes < 1024) {
      return '$sizeInBytes B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Edad de la descarga (en minutos)
  int get ageInMinutes {
    return DateTime.now().difference(downloadedAt).inMinutes;
  }

  /// Verifica si el cache está vencido según el TTL
  bool isExpired(int ttlMinutes) {
    return ageInMinutes >= ttlMinutes;
  }

  RadarData({
    required this.imageBytes,
    required this.downloadedAt,
    required this.sourceUrl,
    this.radarTimestamp,
  });

  /// Constructor desde archivo cacheado
  factory RadarData.fromCache({
    required Uint8List imageBytes,
    required DateTime downloadedAt,
    required String sourceUrl,
  }) {
    return RadarData(
      imageBytes: imageBytes,
      downloadedAt: downloadedAt,
      sourceUrl: sourceUrl,
    );
  }

  @override
  String toString() {
    return 'RadarData{'
        'size: $sizeFormatted, '
        'age: $ageInMinutes min, '
        'downloaded: ${downloadedAt.toIso8601String()}'
        '}';
  }
}