// lib/data/models/storm_nucleus.dart

import 'package:latlong2/latlong.dart';

/// Modelo de un núcleo de tormenta detectado
class StormNucleus {
  /// ID único del núcleo
  final String id;

  /// Posición geográfica del centro del núcleo
  final LatLng position;

  /// Intensidad máxima de reflectividad (dBZ)
  final int maxDbz;

  /// Radio aproximado del núcleo (en kilómetros)
  final double radiusKm;

  /// Cantidad de píxeles que forman el núcleo
  final int pixelCount;

  /// Timestamp de detección
  final DateTime detectedAt;

  StormNucleus({
    required this.id,
    required this.position,
    required this.maxDbz,
    required this.radiusKm,
    required this.pixelCount,
    DateTime? detectedAt,
  }) : detectedAt = detectedAt ?? DateTime.now();

  /// Determina el nivel de peligrosidad según dBZ
  String get dangerLevel {
    if (maxDbz >= 55) return 'ROJO';      // Granizo severo
    if (maxDbz >= 45) return 'NARANJA';   // Granizo probable
    if (maxDbz >= 30) return 'AMARILLO';  // Tormenta fuerte
    return 'VERDE';                        // Precipitación leve
  }

  /// Color asociado al nivel de peligro
  int get colorValue {
    if (maxDbz >= 55) return 0xFFFF0000; // Rojo
    if (maxDbz >= 45) return 0xFFFF9800; // Naranja
    if (maxDbz >= 30) return 0xFFFFEB3B; // Amarillo
    return 0xFF4CAF50;                   // Verde
  }

  /// Descripción legible del núcleo
  String get description {
    if (maxDbz >= 55) return 'Granizo severo';
    if (maxDbz >= 45) return 'Granizo probable';
    if (maxDbz >= 30) return 'Tormenta fuerte';
    return 'Precipitación moderada';
  }

  @override
  String toString() {
    return 'StormNucleus{'
        'id: $id, '
        'position: (${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}), '
        'maxDbz: $maxDbz, '
        'level: $dangerLevel, '
        'radius: ${radiusKm.toStringAsFixed(1)} km'
        '}';
  }

  /// Convierte a Map para serialización
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'maxDbz': maxDbz,
      'radiusKm': radiusKm,
      'pixelCount': pixelCount,
      'dangerLevel': dangerLevel,
      'detectedAt': detectedAt.toIso8601String(),
    };
  }

  /// Crea desde Map (deserialización)
  factory StormNucleus.fromJson(Map<String, dynamic> json) {
    return StormNucleus(
      id: json['id'],
      position: LatLng(json['latitude'], json['longitude']),
      maxDbz: json['maxDbz'],
      radiusKm: json['radiusKm'],
      pixelCount: json['pixelCount'],
      detectedAt: DateTime.parse(json['detectedAt']),
    );
  }
}