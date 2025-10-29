// lib/core/dacc/dacc_cache.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import '../../utils/logger.dart';
import '../../utils/constants.dart';
import '../../data/models/radar_data.dart';

/// Gestor de cache para imágenes del radar DACC
class DACCCache {
  static const String _cacheFileName = 'dacc_radar_latest.png';
  static const String _metadataFileName = 'dacc_radar_metadata.txt';

  /// Obtiene el directorio de cache de la app
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/radar_cache');

    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
      AppLogger.debug('Directorio de cache creado: ${cacheDir.path}');
    }

    return cacheDir;
  }

  /// Guarda una imagen en el cache
  static Future<bool> saveToCache(RadarData radarData) async {
    try {
      AppLogger.start('Guardando imagen en cache');

      final cacheDir = await _getCacheDirectory();

      // Guardar imagen
      final imageFile = File('${cacheDir.path}/$_cacheFileName');
      await imageFile.writeAsBytes(radarData.imageBytes);

      // Guardar metadatos
      final metadataFile = File('${cacheDir.path}/$_metadataFileName');
      final metadata = [
        'downloaded_at=${radarData.downloadedAt.toIso8601String()}',
        'source_url=${radarData.sourceUrl}',
        'size_bytes=${radarData.sizeInBytes}',
      ].join('\n');
      await metadataFile.writeAsString(metadata);

      AppLogger.success(
        'Imagen guardada en cache: ${radarData.sizeFormatted}',
      );
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Error al guardar en cache', e, stackTrace);
      return false;
    }
  }

  /// Carga la imagen desde el cache
  static Future<RadarData?> loadFromCache() async {
    try {
      AppLogger.start('Cargando imagen desde cache');

      final cacheDir = await _getCacheDirectory();
      final imageFile = File('${cacheDir.path}/$_cacheFileName');
      final metadataFile = File('${cacheDir.path}/$_metadataFileName');

      // Verificar que existan ambos archivos
      if (!await imageFile.exists() || !await metadataFile.exists()) {
        AppLogger.warning('No hay imagen en cache');
        return null;
      }

      // Leer imagen
      final imageBytes = await imageFile.readAsBytes();

      // Leer metadatos
      final metadataContent = await metadataFile.readAsString();
      final metadataLines = metadataContent.split('\n');

      DateTime? downloadedAt;
      String? sourceUrl;

      for (final line in metadataLines) {
        if (line.startsWith('downloaded_at=')) {
          downloadedAt = DateTime.parse(line.substring('downloaded_at='.length));
        } else if (line.startsWith('source_url=')) {
          sourceUrl = line.substring('source_url='.length);
        }
      }

      if (downloadedAt == null || sourceUrl == null) {
        AppLogger.warning('Metadatos de cache incompletos');
        return null;
      }

      final radarData = RadarData.fromCache(
        imageBytes: imageBytes,
        downloadedAt: downloadedAt,
        sourceUrl: sourceUrl,
      );

      AppLogger.success(
        'Imagen cargada desde cache: ${radarData.sizeFormatted}, '
            'edad: ${radarData.ageInMinutes} min',
      );

      return radarData;
    } catch (e, stackTrace) {
      AppLogger.error('Error al cargar desde cache', e, stackTrace);
      return null;
    }
  }

  /// Verifica si hay un cache válido (no vencido)
  static Future<bool> hasValidCache() async {
    final radarData = await loadFromCache();

    if (radarData == null) {
      return false;
    }

    final isValid = !radarData.isExpired(AppConstants.cacheTTLMinutes);

    if (isValid) {
      AppLogger.info('Cache válido (edad: ${radarData.ageInMinutes} min)');
    } else {
      AppLogger.warning('Cache vencido (edad: ${radarData.ageInMinutes} min)');
    }

    return isValid;
  }

  /// Limpia el cache (elimina archivos)
  static Future<bool> clearCache() async {
    try {
      AppLogger.start('Limpiando cache');

      final cacheDir = await _getCacheDirectory();
      final imageFile = File('${cacheDir.path}/$_cacheFileName');
      final metadataFile = File('${cacheDir.path}/$_metadataFileName');

      if (await imageFile.exists()) {
        await imageFile.delete();
      }

      if (await metadataFile.exists()) {
        await metadataFile.delete();
      }

      AppLogger.success('Cache limpiado');
      return true;
    } catch (e) {
      AppLogger.error('Error al limpiar cache', e);
      return false;
    }
  }

  /// Obtiene información del cache (para debug/stats)
  static Future<Map<String, dynamic>> getCacheInfo() async {
    final radarData = await loadFromCache();

    if (radarData == null) {
      return {'exists': false};
    }

    return {
      'exists': true,
      'size': radarData.sizeFormatted,
      'age_minutes': radarData.ageInMinutes,
      'downloaded_at': radarData.downloadedAt.toIso8601String(),
      'is_expired': radarData.isExpired(AppConstants.cacheTTLMinutes),
    };
  }
}