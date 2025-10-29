import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Tipos de núcleos según intensidad
enum NucleusType {
  rain,      // 25-40 dBZ
  electric,  // 40-55 dBZ
  hail,      // 55+ dBZ
}

/// Punto de dato del radar
class SyntheticRadarPoint {
  final LatLng coordinate;
  final double dbz;
  final Color color;
  final NucleusType type;

  SyntheticRadarPoint({
    required this.coordinate,
    required this.dbz,
    required this.color,
    required this.type,
  });
}

/// Núcleo de tormenta detectado
class StormNucleus {
  final LatLng center;
  final double maxDbz;
  final double radiusKm;
  final NucleusType type;
  final int pixelCount;

  StormNucleus({
    required this.center,
    required this.maxDbz,
    required this.radiusKm,
    required this.type,
    this.pixelCount = 0,
  });

  String get label {
    switch (type) {
      case NucleusType.hail:
        return 'GRANIZO';
      case NucleusType.electric:
        return 'ELÉCTRICA';
      case NucleusType.rain:
        return 'LLUVIA';
    }
  }
}

/// Servicio de radar (SOLO DATOS REALES)
class SyntheticRadarService {
  /// Convierte dBZ a color según reglas meteorológicas
  static Color? dbzToColor(double dbz) {
    if (dbz < 25) return null; // UMBRAL MÍNIMO

    int r, g, b;
    double alpha;

    if (dbz < 35) {
      // 25-35 dBZ: AZUL (lluvia débil)
      final t = (dbz - 25) / 10;
      r = (100 + t * 30).round();
      g = (150 + t * 50).round();
      b = 255;
      alpha = 0.5 + (t * 0.15);
    } else if (dbz < 45) {
      // 35-45 dBZ: VERDE-AMARILLO (eléctrica)
      final t = (dbz - 35) / 10;
      r = (130 + t * 125).round();
      g = (200 + t * 55).round();
      b = (255 - t * 155).round();
      alpha = 0.65 + (t * 0.15);
    } else if (dbz < 55) {
      // 45-55 dBZ: NARANJA (fuerte)
      final t = (dbz - 45) / 10;
      r = 255;
      g = (255 - t * 100).round();
      b = (100 - t * 100).round();
      alpha = 0.8 + (t * 0.1);
    } else {
      // 55+ dBZ: ROJO-VIOLETA (granizo)
      final t = math.min((dbz - 55) / 20, 1.0);
      r = 255;
      g = (155 - t * 155).round();
      b = (0 + t * 200).round();
      alpha = 0.9 + (t * 0.1);
    }

    return Color.fromRGBO(r, g, b, alpha);
  }

  /// Determina tipo de núcleo
  static NucleusType getNucleusType(double dbz) {
    if (dbz >= 55) return NucleusType.hail;
    if (dbz >= 40) return NucleusType.electric;
    return NucleusType.rain;
  }

  /// Convierte datos reales del DACC a puntos para renderizar
  /// ESTE MÉTODO SE LLAMA DESDE EL ANALIZADOR DE IMÁGENES
  static List<SyntheticRadarPoint> convertRealRadarData(
      List<StormNucleus> nuclei,
      Map<LatLng, double> intensityMap,
      ) {
    final points = <SyntheticRadarPoint>[];

    // VALIDACIÓN: Si no hay núcleos reales, retornar vacío
    if (nuclei.isEmpty || intensityMap.isEmpty) {
      return points;
    }

    // Convertir mapa de intensidad a puntos visuales
    for (final entry in intensityMap.entries) {
      final coord = entry.key;
      final dbz = entry.value;

      if (dbz >= 25) {
        final color = dbzToColor(dbz);
        if (color != null) {
          points.add(SyntheticRadarPoint(
            coordinate: coord,
            dbz: dbz,
            color: color,
            type: getNucleusType(dbz),
          ));
        }
      }
    }

    return points;
  }

  /// SOLO PARA DEBUG/TESTING - NO USAR EN PRODUCCIÓN
  static (List<SyntheticRadarPoint>, List<StormNucleus>) generateTestData() {
    // Retornar vacío en producción
    return ([], []);
  }
}
