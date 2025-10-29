// lib/core/location/permission_handler.dart

import 'package:geolocator/geolocator.dart';
import '../../utils/logger.dart';

/// Resultado de la verificación de permisos
enum PermissionResult {
  granted,           // Permisos concedidos
  denied,            // Permisos denegados (temporal)
  deniedForever,     // Permisos denegados permanentemente
  serviceDisabled,   // Servicio de ubicación deshabilitado
}

/// Manejador centralizado de permisos de ubicación
class AppPermissionHandler {
  /// Verifica y solicita permisos de ubicación si es necesario
  ///
  /// Retorna el estado final de los permisos
  static Future<PermissionResult> checkAndRequestLocationPermission() async {
    AppLogger.start('Verificando permisos de ubicación');

    // 1. Verificar si el servicio de ubicación está habilitado
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.warning('Servicio de ubicación deshabilitado en el dispositivo');
      return PermissionResult.serviceDisabled;
    }

    // 2. Verificar permisos actuales
    LocationPermission permission = await Geolocator.checkPermission();
    AppLogger.debug('Estado inicial de permisos: $permission');

    // 3. Si están denegados permanentemente, no podemos hacer nada
    if (permission == LocationPermission.deniedForever) {
      AppLogger.error('Permisos de ubicación denegados permanentemente');
      return PermissionResult.deniedForever;
    }

    // 4. Si están denegados, solicitar
    if (permission == LocationPermission.denied) {
      AppLogger.info('Solicitando permisos de ubicación al usuario');
      permission = await Geolocator.requestPermission();
      AppLogger.debug('Resultado de solicitud: $permission');

      if (permission == LocationPermission.denied) {
        AppLogger.warning('Usuario denegó permisos de ubicación');
        return PermissionResult.denied;
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.error('Usuario denegó permisos permanentemente');
        return PermissionResult.deniedForever;
      }
    }

    // 5. Permisos concedidos
    AppLogger.success('Permisos de ubicación concedidos');
    return PermissionResult.granted;
  }

  /// Verifica si tenemos permisos SIN solicitar (solo lectura)
  static Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Abre la configuración de la app para que el usuario habilite permisos
  static Future<void> openAppSettings() async {
    AppLogger.info('Abriendo configuración de la app');
    await Geolocator.openAppSettings();
  }

  /// Abre la configuración de ubicación del sistema
  static Future<void> openLocationSettings() async {
    AppLogger.info('Abriendo configuración de ubicación');
    await Geolocator.openLocationSettings();
  }

  /// Obtiene un mensaje legible según el resultado de permisos
  static String getPermissionMessage(PermissionResult result) {
    switch (result) {
      case PermissionResult.granted:
        return 'Permisos de ubicación concedidos';

      case PermissionResult.denied:
        return 'Necesitamos acceso a tu ubicación para mostrarte alertas de tormentas cercanas';

      case PermissionResult.deniedForever:
        return 'Los permisos de ubicación están deshabilitados. '
            'Por favor, habilítalos en la configuración de la app';

      case PermissionResult.serviceDisabled:
        return 'El servicio de ubicación está deshabilitado. '
            'Por favor, actívalo en la configuración del dispositivo';
    }
  }

  /// Obtiene un mensaje detallado para mostrar antes de solicitar permisos (racional)
  static String getPermissionRationale() {
    return 'Granizo necesita acceso a tu ubicación para:\n\n'
        '• Mostrarte tu posición en el mapa\n'
        '• Calcular la distancia a tormentas cercanas\n'
        '• Enviarte alertas cuando haya granizo en tu área\n\n'
        'Tu ubicación nunca se comparte con terceros.';
  }
}