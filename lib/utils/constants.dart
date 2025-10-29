// lib/utils/constants.dart

import 'package:latlong2/latlong.dart';

/// Constantes globales del proyecto Granizo
class AppConstants {
  // Información de la app
  static const String appName = 'Granizo';
  static const String appVersion = '1.0.0';
  static const String packageName = 'com.josecastillo.granizo';

  // Ubicación por defecto: San Rafael, Mendoza, Argentina
  static const LatLng sanRafaelCenter = LatLng(-34.6177, -68.3301);
  static const double defaultZoom = 12.0;

  // Bounds de la zona sur de Mendoza (San Rafael, Gral. Alvear, Malargüe)
  static const LatLng southWest = LatLng(-36.0, -70.0);
  static const LatLng northEast = LatLng(-33.0, -66.5);

  // URLs del DACC - URL REAL CONFIRMADA
  static const String daccBaseUrl = 'https://www2.contingencias.mendoza.gov.ar/radar';
  static const String daccLatestGif = '$daccBaseUrl/latest.gif';  // ← URL CORRECTA
  static const String daccSurGif = '$daccBaseUrl/sur.gif';

  // Endpoint alternativo (si se necesita)
  static const String daccImageEndpoint = '$daccBaseUrl/muestraimagen.php';

  // Parámetros del radar para San Rafael (si se usa endpoint alternativo)
  static const Map<String, String> daccSanRafaelParams = {
    'imagen': 'google.png',
    'sw': '-35.5,-69.5',
    'ne': '-33.5,-67.0',
    'centro': '-34.6,-68.4',
    'zoom': '9',
  };

  // Umbrales de dBZ para alertas
  static const int yellowThreshold = 30; // Amarillo: dBZ >= 30
  static const int orangeThreshold = 45; // Naranja: dBZ >= 45
  static const int redThreshold = 55;    // Rojo: dBZ >= 55

  // Radios de alerta (en kilómetros)
  static const double yellowRadiusKm = 75.0;
  static const double orangeRadiusKm = 45.0;
  static const double redRadiusKm = 25.0;

  // Cooldowns (en minutos)
  static const int yellowCooldownMinutes = 10;
  static const int orangeCooldownMinutes = 15;
  static const int redCooldownMinutes = 20;

  // Cache
  static const int cacheTTLMinutes = 90;

  // Colores de la UI
  static const int primaryColorValue = 0xFF2196F3;
  static const int accentColorValue = 0xFFFF9800;

  // Logging
  static const String logTag = 'GRANIZO_BG';
}