import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' as math;
import 'synthetic_radar_service.dart';

enum AlertLevel {
  yellow, // 🟡 30+ dBZ, ≤75 km
  orange, // 🟠 45+ dBZ, ≤45 km
  red,    // 🔴 55+ dBZ, ≤25 km
}

class AlertConfig {
  static const double yellowDistanceKm = 75.0;
  static const double orangeDistanceKm = 45.0;
  static const double redDistanceKm = 25.0;

  static const double yellowMinDbz = 30.0;
  static const double orangeMinDbz = 45.0;
  static const double redMinDbz = 55.0;

  static const int cooldownMinutes = 12;
}

class WeatherAlert {
  final AlertLevel level;
  final StormNucleus nucleus;
  final double distanceKm;
  final String locationName;
  final DateTime timestamp;

  WeatherAlert({
    required this.level,
    required this.nucleus,
    required this.distanceKm,
    required this.locationName,
    required this.timestamp,
  });

  String get emoji {
    switch (level) {
      case AlertLevel.yellow:
        return '🟡';
      case AlertLevel.orange:
        return '🟠';
      case AlertLevel.red:
        return '🔴';
    }
  }

  String get severityText {
    switch (level) {
      case AlertLevel.yellow:
        return 'Lluvia intensa';
      case AlertLevel.orange:
        return 'Tormenta fuerte';
      case AlertLevel.red:
        return 'Tormenta severa';
    }
  }

  String get message {
    final distance = distanceKm.toStringAsFixed(0);
    return '$emoji $severityText a $distance km de $locationName';
  }
}

class WeatherAlertService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static final Map<String, DateTime> _lastAlertTimestamp = {};
  static bool _initialized = false;
  static bool _permissionGranted = false;

  /// Inicializar y pedir permisos de notificaciones
  static Future<bool> initialize() async {
    if (_initialized) return _permissionGranted;

    // 1) Permiso de notificaciones (Android 13+)
    final status = await Permission.notification.request();
    _permissionGranted = status.isGranted;

    if (!_permissionGranted) {
      // No spamear, solo log
      return false;
    }

    // 2) Configurar plugin
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);

    await _notifications.initialize(
      init,
      onDidReceiveNotificationResponse: _onTap,
    );

    _initialized = true;
    return true;
  }

  static void _onTap(NotificationResponse response) {
    // Opcional: deep link a pantalla de detalles
    // print('notif tap: ${response.payload}');
  }

  /// Evaluar núcleos y emitir alertas SOLO si hay permiso
  static Future<List<WeatherAlert>> evaluateAndNotify(
      LatLng userLocation,
      List<StormNucleus> nuclei,
      ) async {
    if (!_initialized || !_permissionGranted) {
      await initialize();
    }
    if (!_permissionGranted) return [];

    final alerts = <WeatherAlert>[];
    if (nuclei.isEmpty) return alerts;

    for (final n in nuclei) {
      final dKm = _distanceKm(
        userLocation.latitude,
        userLocation.longitude,
        n.center.latitude,
        n.center.longitude,
      );

      AlertLevel? level;
      if (n.maxDbz >= AlertConfig.redMinDbz && dKm <= AlertConfig.redDistanceKm) {
        level = AlertLevel.red;
      } else if (n.maxDbz >= AlertConfig.orangeMinDbz &&
          dKm <= AlertConfig.orangeDistanceKm) {
        level = AlertLevel.orange;
      } else if (n.maxDbz >= AlertConfig.yellowMinDbz &&
          dKm <= AlertConfig.yellowDistanceKm) {
        level = AlertLevel.yellow;
      }

      if (level == null) continue;

      final key = '${n.center.latitude}_${n.center.longitude}';
      final now = DateTime.now();
      final last = _lastAlertTimestamp[key];
      if (last != null &&
          now.difference(last).inMinutes < AlertConfig.cooldownMinutes) {
        continue;
      }

      final name = _nearestName(n.center);

      final alert = WeatherAlert(
        level: level,
        nucleus: n,
        distanceKm: dKm,
        locationName: name,
        timestamp: now,
      );

      await _send(alert);
      _lastAlertTimestamp[key] = now;
      alerts.add(alert);
    }

    return alerts;
  }

  static Future<void> _send(WeatherAlert a) async {
    final android = AndroidNotificationDetails(
      'weather_alerts',
      'Alertas Meteorológicas',
      channelDescription: 'Notificaciones de tormentas cercanas',
      importance: _importance(a.level),
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );
    final details = NotificationDetails(android: android);

    await _notifications.show(
      a.timestamp.millisecondsSinceEpoch % 100000,
      a.severityText,
      a.message,
      details,
      payload: '${a.level}_${a.distanceKm}',
    );
  }

  static Importance _importance(AlertLevel l) {
    switch (l) {
      case AlertLevel.red:
        return Importance.max;
      case AlertLevel.orange:
        return Importance.high;
      case AlertLevel.yellow:
        return Importance.defaultImportance;
    }
  }

  static double _distanceKm(
      double lat1,
      double lon1,
      double lat2,
      double lon2,
      ) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static String _nearestName(LatLng p) {
    final refs = {
      'Mendoza': LatLng(-32.8908, -68.8272),
      'San Rafael': LatLng(-34.6177, -68.3301),
      'Maipú': LatLng(-32.9833, -68.7833),
      'Godoy Cruz': LatLng(-32.9269, -68.8450),
      'Luján de Cuyo': LatLng(-33.0333, -68.8833),
      'Tunuyán': LatLng(-33.5833, -69.0167),
      'San Martín': LatLng(-33.0808, -68.4681),
      'Lavalle': LatLng(-32.7333, -68.5833),
      'Malargüe': LatLng(-35.4667, -69.5833),
    };

    double min = double.infinity;
    String name = 'tu ubicación';
    for (final e in refs.entries) {
      final d = _distanceKm(
        p.latitude,
        p.longitude,
        e.value.latitude,
        e.value.longitude,
      );
      if (d < min) {
        min = d;
        name = e.key;
      }
    }
    return name;
  }

  static void cleanOldCooldowns() {
    final now = DateTime.now();
    _lastAlertTimestamp
        .removeWhere((_, t) => now.difference(t).inHours > 2);
  }
}
