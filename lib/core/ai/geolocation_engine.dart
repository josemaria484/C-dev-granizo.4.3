// lib/core/ai/geolocation_engine.dart

import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import '../../utils/logger.dart';

/// Motor de geolocalización para convertir píxeles de imagen a coordenadas
class GeolocationEngine {
  final LatLng southWest;
  final LatLng northEast;
  final int imageWidth;
  final int imageHeight;

  late final double _latPerPixel;
  late final double _lonPerPixel;

  GeolocationEngine({
    required this.southWest,
    required this.northEast,
    required this.imageWidth,
    required this.imageHeight,
  }) {
    _latPerPixel = (northEast.latitude - southWest.latitude) / imageHeight;
    _lonPerPixel = (northEast.longitude - southWest.longitude) / imageWidth;

    AppLogger.debug(
      'GeolocationEngine: ${imageWidth}x${imageHeight}, '
          'bounds: (${southWest.latitude.toStringAsFixed(2)}, ${southWest.longitude.toStringAsFixed(2)}) → '
          '(${northEast.latitude.toStringAsFixed(2)}, ${northEast.longitude.toStringAsFixed(2)})',
    );
  }

  LatLng pixelToLatLng(double x, double y) {
    final lat = northEast.latitude - (y * _latPerPixel);
    final lon = southWest.longitude + (x * _lonPerPixel);
    return LatLng(lat, lon);
  }

  double getPixelAreaKm2() {
    final centerLat = (southWest.latitude + northEast.latitude) / 2;
    final kmPerDegLat = 111.0;
    final kmPerDegLon = 111.0 * math.cos(centerLat * math.pi / 180);
    final latKm = _latPerPixel * kmPerDegLat;
    final lonKm = _lonPerPixel * kmPerDegLon;
    return latKm * lonKm;
  }

  double estimateRadiusKm(int pixelCount) {
    final areaKm2 = pixelCount * getPixelAreaKm2();
    return math.sqrt(areaKm2 / math.pi);
  }

  /// Verifica si una posición está dentro de los bounds
  bool isWithinBounds(LatLng position) {
    return position.latitude >= southWest.latitude &&
        position.latitude <= northEast.latitude &&
        position.longitude >= southWest.longitude &&
        position.longitude <= northEast.longitude;
  }
}

class GeolocationEngineFactory {
  /// Crea engine para el GIF completo del DACC (cubre gran parte de Argentina)
  ///
  /// El latest.gif del DACC cubre un área muy grande, necesitamos bounds aproximados
  static GeolocationEngine forDACCLatestGif(int imageWidth, int imageHeight) {
    // Bounds aproximados del latest.gif (cubre desde Buenos Aires hasta San Juan)
    // Estos valores son estimados y pueden necesitar ajuste
    return GeolocationEngine(
      southWest: const LatLng(-40.0, -72.0),  // Sur: hasta Neuquén/La Pampa
      northEast: const LatLng(-28.0, -60.0),  // Norte: hasta Catamarca/La Rioja
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }

  /// Crea engine para toda Mendoza
  static GeolocationEngine forMendozaComplete(int imageWidth, int imageHeight) {
    return GeolocationEngine(
      southWest: const LatLng(-37.5, -71.0),
      northEast: const LatLng(-31.0, -66.0),
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }
}