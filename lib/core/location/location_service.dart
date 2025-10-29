// lib/core/location/location_service.dart

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../utils/logger.dart';

/// Servicio centralizado para manejo de ubicación GPS
class LocationService {
  /// Obtiene la ubicación actual del usuario
  ///
  /// Retorna las coordenadas o null si hay error
  static Future<LatLng?> getCurrentLocation() async {
    try {
      AppLogger.start('Obteniendo ubicación GPS');

      // Obtener posición
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final location = LatLng(position.latitude, position.longitude);

      AppLogger.success(
        'Ubicación obtenida: ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)} '
            '(precisión: ${position.accuracy.toStringAsFixed(1)}m)',
      );

      return location;
    } catch (e, stackTrace) {
      AppLogger.error('Error al obtener ubicación', e, stackTrace);
      return null;
    }
  }

  /// Obtiene la posición con todos los detalles
  static Future<Position?> getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return position;
    } catch (e) {
      AppLogger.error('Error al obtener posición', e);
      return null;
    }
  }

  /// Obtiene la última ubicación conocida (más rápido, menos preciso)
  static Future<LatLng?> getLastKnownLocation() async {
    try {
      AppLogger.debug('Obteniendo última ubicación conocida');

      final position = await Geolocator.getLastKnownPosition();

      if (position == null) {
        AppLogger.warning('No hay última ubicación conocida');
        return null;
      }

      final location = LatLng(position.latitude, position.longitude);

      AppLogger.info(
        'Última ubicación conocida: ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}',
      );

      return location;
    } catch (e) {
      AppLogger.error('Error al obtener última ubicación', e);
      return null;
    }
  }

  /// Calcula la distancia entre dos puntos (en kilómetros)
  static double calculateDistance(LatLng from, LatLng to) {
    return Geolocator.distanceBetween(
      from.latitude,
      from.longitude,
      to.latitude,
      to.longitude,
    ) / 1000; // Convertir metros a kilómetros
  }

  /// Verifica si el servicio de ubicación está habilitado
  static Future<bool> isLocationServiceEnabled() async {
    final enabled = await Geolocator.isLocationServiceEnabled();

    if (!enabled) {
      AppLogger.warning('Servicio de ubicación deshabilitado');
    }

    return enabled;
  }

  /// Stream de ubicación en tiempo real (para seguimiento continuo)
  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Actualizar cada 10 metros
      ),
    );
  }
}