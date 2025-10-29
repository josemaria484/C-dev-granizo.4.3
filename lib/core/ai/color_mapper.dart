// lib/core/ai/color_mapper.dart

import 'dart:ui';

/// Mapeador de colores RGB a valores de reflectividad dBZ
///
/// Basado en la paleta estándar del radar DACC de Mendoza
class ColorMapper {
  /// Estima el valor de dBZ a partir de un color RGB
  ///
  /// Retorna -1 si es fondo/mapa base (verde)
  /// Retorna 0 si no hay eco significativo
  static int estimateDBZ(int r, int g, int b) {
    // FONDO: Verde del mapa base → ignorar
    if (_isMapBackground(r, g, b)) {
      return -1;
    }

    // SIN ECO: Negro o muy oscuro
    if (r < 30 && g < 30 && b < 30) {
      return 0;
    }

    // AZUL CLARO: Precipitación débil (15-25 dBZ)
    if (b > 200 && r < 120 && g > 100 && g < 220) {
      return 20;
    }

    // AZUL INTENSO: Precipitación moderada (25-35 dBZ)
    if (b > 150 && b < 255 && r < 100 && g < 150) {
      return 30;
    }

    // VIOLETA/MAGENTA: Tormenta fuerte (35-45 dBZ)
    if (r > 120 && b > 120 && g < 120) {
      // Distinguir entre violeta claro y oscuro
      if (r > 180 && b > 180) {
        return 42; // Violeta intenso
      }
      return 38; // Violeta claro
    }

    // AMARILLO: Granizo probable (45-55 dBZ)
    if (r > 200 && g > 200 && b < 120) {
      if (r > 240 && g > 240) {
        return 52; // Amarillo brillante
      }
      return 48; // Amarillo medio
    }

    // NARANJA: Granizo confirmado (55-60 dBZ)
    if (r > 200 && g > 80 && g < 200 && b < 100) {
      return 57;
    }

    // ROJO: Granizo severo (60+ dBZ)
    if (r > 200 && g < 100 && b < 100) {
      if (r > 240 && g < 50) {
        return 65; // Rojo intenso
      }
      return 62; // Rojo medio
    }

    // BLANCO: Reflectividad extrema (65+ dBZ)
    if (r > 230 && g > 230 && b > 230) {
      return 68;
    }

    // Default: sin eco o color no reconocido
    return 0;
  }

  /// Verifica si el color corresponde al mapa base (verde)
  static bool _isMapBackground(int r, int g, int b) {
    // Verde típico del mapa topográfico del DACC
    return g > 80 && r < 120 && b < 120 && g > r && g > b;
  }

  /// Verifica si el píxel es parte del mapa base
  static bool isMapBackground(int r, int g, int b) {
    return _isMapBackground(r, g, b);
  }

  /// Retorna si un valor de dBZ es significativo (≥ umbral mínimo)
  static bool isSignificant(int dbz, {int minThreshold = 15}) {
    return dbz >= minThreshold && dbz != -1;
  }

  /// Obtiene el color sintético para un valor de dBZ dado
  ///
  /// Usado para generar el overlay sintético limpio
  static Color getSyntheticColor(int dbz, {double opacity = 0.8}) {
    if (dbz < 5) {
      return Color.fromRGBO(0, 0, 0, 0); // Transparente
    } else if (dbz < 25) {
      return Color.fromRGBO(100, 200, 255, opacity); // Azul claro
    } else if (dbz < 35) {
      return Color.fromRGBO(50, 100, 255, opacity); // Azul intenso
    } else if (dbz < 45) {
      return Color.fromRGBO(180, 50, 255, opacity); // Violeta
    } else if (dbz < 55) {
      return Color.fromRGBO(255, 255, 50, opacity); // Amarillo
    } else if (dbz < 60) {
      return Color.fromRGBO(255, 150, 50, opacity); // Naranja
    } else if (dbz < 65) {
      return Color.fromRGBO(255, 50, 50, opacity); // Rojo
    } else {
      return Color.fromRGBO(255, 255, 255, opacity); // Blanco (extremo)
    }
  }

  /// Obtiene una descripción textual del nivel de intensidad
  static String getIntensityDescription(int dbz) {
    if (dbz < 15) return 'Sin precipitación';
    if (dbz < 25) return 'Lluvia débil';
    if (dbz < 35) return 'Lluvia moderada';
    if (dbz < 45) return 'Lluvia intensa';
    if (dbz < 55) return 'Tormenta severa';
    if (dbz < 60) return 'Granizo probable';
    if (dbz < 65) return 'Granizo confirmado';
    return 'Granizo severo';
  }
}