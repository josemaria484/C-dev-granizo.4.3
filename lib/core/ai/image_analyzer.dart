import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../utils/logger.dart' as log;
import '../../data/models/storm_nucleus.dart';
import '../../data/models/radar_data.dart';
import 'geolocation_engine.dart';
import 'nucleus_detector.dart';

class AnalysisResult {
  final List<StormNucleus> nuclei;
  final img.Image? processedImage;
  final DateTime analyzedAt;
  final Duration analysisTime;

  const AnalysisResult({
    required this.nuclei,
    required this.processedImage,
    required this.analyzedAt,
    required this.analysisTime,
  });
}

class ImageAnalyzer {
  static img.Image? extractLastFrame(Uint8List bytes) {
    try {
      final anim = img.decodeGifAnimation(bytes);
      if (anim != null && anim.length > 0) {
        log.AppLogger.info('GIF tiene ${anim.length} frames');
        final last = anim.frames.last.image;
        log.AppLogger.success('Último frame extraído: ${last.width}x${last.height}');
        return last;
      }
    } catch (_) {}
    final still = img.decodeImage(bytes);
    if (still != null) {
      log.AppLogger.info('Imagen estática: ${still.width}x${still.height}');
    } else {
      log.AppLogger.error('No se pudo decodificar la imagen');
    }
    return still;
  }

  static Future<AnalysisResult> analyzeRadarImage(
    RadarData radarData, {
    bool tryGifFirst = true,
  }) async {
    final started = DateTime.now();
    final List<StormNucleus> nuclei = [];

    img.Image? image;
    image = tryGifFirst
        ? extractLastFrame(radarData.imageBytes)
        : img.decodeImage(radarData.imageBytes);

    if (image == null) {
      return AnalysisResult(
        nuclei: const [],
        processedImage: null,
        analyzedAt: DateTime.now(),
        analysisTime: DateTime.now().difference(started),
      );
    }

    final geoEngine = GeolocationEngineFactory.forMendozaComplete(
      radarCenterLat: radarData.centerLat,
      radarCenterLon: radarData.centerLon,
    );
    final detector = NucleusDetector(geoEngine);
    final detected = detector.detectNuclei(image);
    nuclei.addAll(detected);

    return AnalysisResult(
      nuclei: nuclei,
      processedImage: image,
      analyzedAt: DateTime.now(),
      analysisTime: DateTime.now().difference(started),
    );
  }
}
