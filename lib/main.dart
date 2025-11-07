import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';

import 'utils/constants.dart';
import 'utils/logger.dart';
import 'core/location/location_service.dart';
import 'core/location/permission_handler.dart';
import 'core/dacc/dacc_downloader.dart';
import 'core/ai/image_analyzer.dart';
import 'data/models/cloud_overlay.dart';
import 'data/models/radar_data.dart';
// Nota: no dependemos del tipo exacto del núcleo real; operamos en runtime.

import 'services/weather_alert_service.dart';
import 'services/cloud_overlay_service.dart';
import 'services/synthetic_radar_service.dart' as syn;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.info('Iniciando ${AppConstants.appName} v${AppConstants.appVersion}');
  runApp(const GranizoApp());
}

class GranizoApp extends StatelessWidget {
  const GranizoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Color(AppConstants.primaryColorValue)),
        useMaterial3: true,
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  bool _isRefreshing = false;
  bool _isLocating = false;

  RadarData? _currentRadarData;
  List<dynamic> _detectedNuclei = []; // núcleos reales, tipo libre
  CloudOverlay? _cloudOverlay;

  LatLng? _userLocation;
  Timer? _alertTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.info('MapScreen inicializado');
    WeatherAlertService.initialize();
    _loadInitialRadar();
    _startAlertMonitoring();
  }

  @override
  void dispose() {
    _alertTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialRadar() async {
    try {
      final (radarData, _) = await DACCDownloader.getLatestRadar();
      if (radarData != null) {
        final analysis = await ImageAnalyzer.analyzeRadarImage(
          radarData,
          minDbz: 40,
          minPixels: 1000,
        );
        CloudOverlay? overlay;
        if (analysis.processedImage != null) {
          overlay = await CloudOverlayService.buildOverlay(
            analysis.processedImage!,
            minDbz: 25,
          );
        }
        if (!mounted) return;
        setState(() {
          _currentRadarData = radarData;
          _detectedNuclei = analysis.nuclei; // lista de núcleos del modelo real
          _cloudOverlay = overlay;
        });
        await _checkWeatherAlerts();
      }
    } catch (e) {
      AppLogger.error('Error al cargar radar inicial', e);
    }
  }

  void _startAlertMonitoring() {
    _alertTimer = Timer.periodic(const Duration(minutes: 5), (t) async {
      if (!mounted) return;
      try {
        final pos = await LocationService.getCurrentLocation();
        if (pos != null) _userLocation = pos;
      } catch (e) {
        AppLogger.error('Ubicación para alertas', e);
      }
      WeatherAlertService.cleanOldCooldowns();
      await _checkWeatherAlerts();
    });
  }

  Future<void> _checkWeatherAlerts() async {
    if (_userLocation == null || _detectedNuclei.isEmpty) return;

    final alertsNuclei = _toAlertNuclei(_detectedNuclei);
    if (alertsNuclei.isEmpty) return;

    final alerts = await WeatherAlertService.evaluateAndNotify(
      _userLocation!,
      alertsNuclei,
    );

    if (alerts.isNotEmpty) {
      AppLogger.warning(
        '⚠️ ${alerts.length} alertas emitidas '
            '(rojas=${alerts.where((a) => a.level.name == "red").length}, '
            'naranjas=${alerts.where((a) => a.level.name == "orange").length}, '
            'amarillas=${alerts.where((a) => a.level.name == "yellow").length})',
      );
    }
  }

  // Adaptador robusto: acepta cualquier forma de núcleo real
  List<syn.StormNucleus> _toAlertNuclei(List<dynamic> src) {
    syn.NucleusType _type(double dbz) => syn.SyntheticRadarService.getNucleusType(dbz);
    double _heuristicRadius(double dbz) {
      if (dbz >= 55.0) return 25.0;
      if (dbz >= 40.0) return 30.0;
      return 35.0;
    }

    LatLng? _extractCenter(dynamic n) {
      try {
        // center: LatLng
        final c = n.center;
        if (c is LatLng) return c;
      } catch (_) {}
      try {
        // lat/lon
        final lat = (n.lat ?? n.latitude) as num?;
        final lon = (n.lon ?? n.longitude) as num?;
        if (lat != null && lon != null) return LatLng(lat.toDouble(), lon.toDouble());
      } catch (_) {}
      // fallback nulo
      return null;
    }

    double _extractDbz(dynamic n) {
      try {
        final v = (n.maxDbz ?? n.dbz) as num?;
        return (v ?? 0).toDouble();
      } catch (_) {
        return 0.0;
      }
    }

    double? _extractRadius(dynamic n) {
      try {
        final r = n.radiusKm as num?;
        return r?.toDouble();
      } catch (_) {
        return null;
      }
    }

    final out = <syn.StormNucleus>[];
    for (final n in src) {
      final center = _extractCenter(n);
      if (center == null) continue;

      final dbz = _extractDbz(n);
      if (dbz < 25.0) continue;

      final r = _extractRadius(n) ?? _heuristicRadius(dbz);

      out.add(syn.StormNucleus(
        center: center,
        maxDbz: dbz,
        radiusKm: r,
        type: _type(dbz),
        pixelCount: 0,
      ));
    }
    return out;
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      final (radarData, _) = await DACCDownloader.getLatestRadar(forceRefresh: true);
      if (radarData == null) throw Exception('No se pudo obtener datos del radar');

      final analysis = await ImageAnalyzer.analyzeRadarImage(
        radarData,
        minDbz: 40,
        minPixels: 1000,
      );

      CloudOverlay? overlay;
      if (analysis.processedImage != null) {
        overlay = await CloudOverlayService.buildOverlay(
          analysis.processedImage!,
          minDbz: 25,
        );
      }

      if (!mounted) return;
      setState(() {
        _currentRadarData = radarData;
        _detectedNuclei = analysis.nuclei;
        _cloudOverlay = overlay;
      });

      final levels = analysis.nucleiByLevel;
      final msg = analysis.nuclei.isEmpty
          ? 'Sin tormentas significativas ✅'
          : 'Tormentas detectadas: 🔴${levels['red']} 🟠${levels['orange']} 🟡${levels['yellow']}';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: analysis.nuclei.isEmpty ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );

      await _checkWeatherAlerts();
    } catch (e, st) {
      AppLogger.error('Error al refrescar', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Error al actualizar radar'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ));
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _onMyLocation() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);

    try {
      final perm = await AppPermissionHandler.checkAndRequestLocationPermission();
      if (perm != PermissionResult.granted) {
        final msg = AppPermissionHandler.getPermissionMessage(perm);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(msg), backgroundColor: Colors.orange, duration: const Duration(seconds: 4)),
          );
        }
        return;
      }

      final loc = await LocationService.getCurrentLocation();
      if (loc == null) throw Exception('No se pudo obtener la ubicación');

      _userLocation = loc;
      _mapController.move(loc, AppConstants.defaultZoom);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Tu ubicación: ${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}'),
          duration: const Duration(seconds: 2),
        ));
      }

      await _checkWeatherAlerts();
    } catch (e) {
      AppLogger.error('Error al obtener ubicación', e);
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _onShare() async {
    try {
      final center = _mapController.camera.center;
      final radarInfo = _currentRadarData != null ? '\nRadar: ${_currentRadarData!.ageInMinutes} min' : '';
      final nucleiInfo = _detectedNuclei.isNotEmpty ? '\nTormentas detectadas: ${_detectedNuclei.length}' : '';

      final msg = '''
🌩️ Granizo - Mendoza

📍 ${center.latitude.toStringAsFixed(4)}, ${center.longitude.toStringAsFixed(4)}$radarInfo$nucleiInfo

${AppConstants.appName} v${AppConstants.appVersion}
''';
      await Share.share(msg);
    } catch (e) {
      AppLogger.error('Error al compartir', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: AppConstants.sanRafaelCenter,
              initialZoom: AppConstants.defaultZoom,
              minZoom: 8.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: AppConstants.packageName,
              ),
              if (_cloudOverlay?.hasPixels == true)
                OverlayImageLayer(
                  overlayImages: [
                    OverlayImage(
                      bounds: _cloudOverlay!.bounds,
                      imageProvider: MemoryImage(_cloudOverlay!.imageBytes),
                    ),
                  ],
                ),
            ],
          ),

          // Indicador de edad del radar
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _currentRadarData != null
                    ? '📡 Radar: ${_currentRadarData!.ageInMinutes} min'
                    : '📡 Cargando...',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          // Botones existentes
          Positioned(
            right: 16,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'btn_refresh',
                  onPressed: _isRefreshing ? null : _onRefresh,
                  tooltip: 'Refrescar radar',
                  child: _isRefreshing
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'btn_location',
                  onPressed: _isLocating ? null : _onMyLocation,
                  tooltip: 'Mi ubicación',
                  child: _isLocating
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 12),
                FloatingActionButton(
                  heroTag: 'btn_share',
                  onPressed: _onShare,
                  tooltip: 'Compartir',
                  child: const Icon(Icons.share),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
