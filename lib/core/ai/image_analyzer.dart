// lib/core/ai/image_analyzer.dart

import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../../utils/logger.dart';
import '../../data/models/storm_nucleus.dart';
import '../../data/models/radar_data.dart';
import 'geolocation_engine.dart';
import 'nucleus_detector.dart';

/// Resultado del análisis de una imagen de radar
class AnalysisResult {
  final List<StormNucleus> nuclei;
  final img.Image? processedImage;
  final DateTime analyzedAt;
  final Duration analysisTime;

  AnalysisResult({
    required this.nuclei,
    this.processedImage,
    required this.analyzedAt,
    required this.analysisTime,
  });

  /// Cantidad de núcleos por nivel
  Map<String, int> get nucleiByLevel {
    int red = 0, orange = 0, yellow = 0;

    for (final nucleus in nuclei) {
      if (nucleus.maxDbz >= 55) {
        red++;
      } else if (nucleus.maxDbz >= 45) {
        orange++;
      } else if (nucleus.maxDbz >= 30) {
        yellow++;
      }
    }

    return {'red': red, 'orange': orange, 'yellow': yellow};
  }

  @override
  String toString() {
    final levels = nucleiByLevel;
    return 'AnalysisResult{'
        'nuclei: ${nuclei.length}, '
        'levels: R=${levels['red']}, O=${levels['orange']}, Y=${levels['yellow']}, '
        'time: ${analysisTime.inMilliseconds}ms'
        '}';
  }
}

/// Analizador de imágenes del radar con IA local
class ImageAnalyzer {
  /// Extrae el último frame de un GIF animado
  static img.Image? extractLastFrame(Uint8List gifBytes) {
    try {
      AppLogger.info('Extrayendo último frame del GIF');

      // Decodificar GIF completo
      final gif = img.decodeGif(gifBytes);

      if (gif == null) {
        AppLogger.error('No se pudo decodificar el GIF');
        return null;
      }

      // Obtener los frames disponibles
      final frames = gif.frames;
      AppLogger.info('GIF tiene ${frames.length} frames');

      if (frames.isEmpty) {
        AppLogger.error('GIF sin frames');
        return null;
      }

      // Obtener el último frame (el más reciente)
      final lastFrame = frames.last;

      AppLogger.success('Último frame extraído: ${lastFrame.width}x${lastFrame.height}');

      return lastFrame;
    } catch (e) {
      AppLogger.error('Error al extraer frame del GIF', e);
      return null;
    }
  }

  /// Analiza una imagen del radar DACC
  ///
  /// [radarData] Datos del radar descargados
  /// [minDbz] Umbral mínimo de detección (default: 30)
  /// [minPixels] Mínimo de píxeles para considerar tormenta real (default: 100)
  static Future<AnalysisResult> analyzeRadarImage(
      RadarData radarData, {
        int minDbz = 30,
        int minPixels = 100,  // Umbral para filtrar ruido
      }) async {
    final startTime = DateTime.now();
    AppLogger.start('Analizando imagen del radar con IA local');

    try {
      // Validar tamaño de datos
      if (radarData.imageBytes.isEmpty) {
        throw Exception('Datos de imagen vacíos');
      }

      AppLogger.info('Tamaño de datos: ${radarData.sizeFormatted}');

      // Detectar si es GIF
      final isGif = radarData.imageBytes.length >= 3 &&
          radarData.imageBytes[0] == 0x47 &&
          radarData.imageBytes[1] == 0x49 &&
          radarData.imageBytes[2] == 0x46;

      img.Image? image;

      if (isGif) {
        AppLogger.info('Formato detectado: GIF animado');
        // Extraer último frame del GIF
        image = extractLastFrame(radarData.imageBytes);
      } else {
        AppLogger.info('Intentando decodificar como imagen estática');
        // Intentar decodificar como PNG/JPG
        image = img.decodeImage(radarData.imageBytes);
      }

      // Si todo falló
      if (image == null) {
        AppLogger.error('No se pudo decodificar la imagen');
        throw Exception('No se pudo decodificar la imagen');
      }

      AppLogger.success('Imagen decodificada: ${image.width}x${image.height}');

      // Crear motor de geolocalización para toda Mendoza
      final geoEngine = GeolocationEngineFactory.forMendozaComplete(
        image.width,
        image.height,
      );

      AppLogger.debug(geoEngine.toString());

      // Detectar núcleos con umbral de píxeles para filtrar ruido
      final detector = NucleusDetector(geoEngine);
      final nuclei = await detector.detectNuclei(
        image,
        minDbz: minDbz,
        minPixels: minPixels,  // Filtrar tormentas pequeñas
      );

      // Calcular tiempo de análisis
      final endTime = DateTime.now();
      final analysisTime = endTime.difference(startTime);

      final result = AnalysisResult(
        nuclei: nuclei,
        processedImage: image,
        analyzedAt: endTime,
        analysisTime: analysisTime,
      );

      AppLogger.success('Análisis completado: $result');

      return result;
    } catch (e, stackTrace) {
      AppLogger.error('Error al analizar imagen', e, stackTrace);

      // Retornar resultado vacío en lugar de lanzar excepción
      final endTime = DateTime.now();
      return AnalysisResult(
        nuclei: [],
        processedImage: null,
        analyzedAt: endTime,
        analysisTime: endTime.difference(startTime),
      );
    }
  }
}