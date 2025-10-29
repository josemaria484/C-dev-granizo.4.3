// lib/core/dacc/dacc_downloader.dart

import 'dart:typed_data';
import '../../utils/logger.dart';
import '../../data/models/radar_data.dart';
import 'dacc_client.dart';
import 'dacc_cache.dart';

/// Resultado de la operación de descarga
enum DownloadResult {
  success,           // Descarga exitosa desde DACC
  usedCache,         // Se usó cache válido
  failed,            // Error al descargar
  noInternet,        // Sin conexión a internet
}

/// Downloader principal del radar DACC con cache automático
class DACCDownloader {
  /// Descarga la última imagen del radar, con fallback a cache
  ///
  /// [forceRefresh] Si es true, ignora el cache y descarga nueva imagen
  ///
  /// Retorna la imagen o null si no se pudo obtener
  static Future<RadarData?> downloadLatestRadar({
    bool forceRefresh = false,
  }) async {
    AppLogger.start('Descargando radar del DACC');

    // 1. Si no es refresh forzado, intentar usar cache válido
    if (!forceRefresh) {
      final hasValid = await DACCCache.hasValidCache();
      if (hasValid) {
        AppLogger.info('Usando cache válido (no es necesario descargar)');
        return await DACCCache.loadFromCache();
      }
    }

    // 2. Descargar nueva imagen desde DACC
    AppLogger.info('Cache vencido o refresh forzado, descargando nueva imagen');

    // USAR URL CORRECTA: latest.gif
    Uint8List? imageBytes = await DACCClient.downloadLatestGif();

    // Si latest.gif falla, intentar sur.gif como backup
    if (imageBytes == null) {
      AppLogger.warning('latest.gif falló, intentando sur.gif como backup');
      imageBytes = await DACCClient.downloadSurGif();
    }

    // Si ambos fallan, intentar endpoint estático
    if (imageBytes == null) {
      AppLogger.warning('GIFs fallaron, intentando endpoint estático');
      imageBytes = await DACCClient.downloadStaticPng();
    }

    if (imageBytes == null) {
      AppLogger.warning('No se pudo descargar imagen, intentando usar cache antiguo');
      // Fallback: usar cache aunque esté vencido
      return await DACCCache.loadFromCache();
    }

    // 3. Crear objeto RadarData
    final radarData = RadarData(
      imageBytes: imageBytes,
      downloadedAt: DateTime.now(),
      sourceUrl: 'DACC Latest - Mendoza',
    );

    // 4. Guardar en cache
    await DACCCache.saveToCache(radarData);

    AppLogger.success('Radar descargado y cacheado exitosamente: ${radarData.sizeFormatted}');
    return radarData;
  }

  /// Obtiene el radar más reciente (cache o descarga)
  ///
  /// Esta es la función principal que deberías usar en la app
  static Future<(RadarData?, DownloadResult)> getLatestRadar({
    bool forceRefresh = false,
  }) async {
    try {
      // 1. Si no forzamos refresh, intentar cache válido
      if (!forceRefresh) {
        final cachedData = await DACCCache.loadFromCache();
        if (cachedData != null &&
            !cachedData.isExpired(90)) {
          AppLogger.info('Usando radar desde cache válido');
          return (cachedData, DownloadResult.usedCache);
        }
      }

      // 2. Verificar conectividad al DACC
      final isAvailable = await DACCClient.checkAvailability();
      if (!isAvailable) {
        AppLogger.warning('DACC no disponible, usando cache');
        final cachedData = await DACCCache.loadFromCache();
        return (cachedData, DownloadResult.noInternet);
      }

      // 3. Descargar nueva imagen
      final radarData = await downloadLatestRadar(forceRefresh: true);

      if (radarData == null) {
        AppLogger.error('Descarga falló completamente');
        return (null, DownloadResult.failed);
      }

      return (radarData, DownloadResult.success);
    } catch (e, stackTrace) {
      AppLogger.error('Error en getLatestRadar', e, stackTrace);

      // Último intento: devolver cache aunque esté vencido
      final cachedData = await DACCCache.loadFromCache();
      return (cachedData, DownloadResult.failed);
    }
  }

  /// Descarga el GIF animado más reciente
  static Future<Uint8List?> downloadLatestAnimation() async {
    AppLogger.start('Descargando GIF animado más reciente');
    return await DACCClient.downloadLatestGif();
  }

  /// Pre-carga el radar en background (útil para inicialización)
  static Future<void> preloadRadar() async {
    AppLogger.info('Pre-cargando radar en background');
    await getLatestRadar(forceRefresh: false);
  }

  /// Limpia el cache y fuerza nueva descarga
  static Future<RadarData?> refreshAndClearCache() async {
    AppLogger.info('Limpiando cache y descargando nueva imagen');
    await DACCCache.clearCache();
    return await downloadLatestRadar(forceRefresh: true);
  }
}