// lib/core/dacc/dacc_client.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../../utils/logger.dart';
import '../../utils/constants.dart';

/// Cliente HTTP para comunicación con el DACC
class DACCClient {
  static final http.Client _httpClient = http.Client();

  /// Headers por defecto para requests al DACC
  static final Map<String, String> _defaultHeaders = {
    'User-Agent': '${AppConstants.appName}/${AppConstants.appVersion} (Meteorological Analysis)',
    'Accept': 'image/png, image/gif, image/*',
  };

  /// Descarga una imagen del DACC
  ///
  /// [url] URL completa de la imagen
  /// [timeout] Tiempo máximo de espera (default: 30 segundos)
  ///
  /// Retorna los bytes de la imagen o null si hay error
  static Future<Uint8List?> downloadImage(
      String url, {
        Duration timeout = const Duration(seconds: 30),
      }) async {
    try {
      AppLogger.start('Descargando imagen del DACC: $url');

      final response = await _httpClient
          .get(Uri.parse(url), headers: _defaultHeaders)
          .timeout(timeout);

      AppLogger.debug('Status code: ${response.statusCode}');
      AppLogger.debug('Content-Type: ${response.headers['content-type']}');
      AppLogger.debug('Content-Length: ${response.headers['content-length']}');

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;

        // Validar que sea realmente una imagen
        final contentType = response.headers['content-type'] ?? '';

        if (!contentType.contains('image') && bytes.length < 100) {
          AppLogger.error(
            'Respuesta no es una imagen válida',
            'Content-Type: $contentType, Size: ${bytes.length} bytes',
          );

          // Intentar leer como texto para debug
          try {
            final textContent = String.fromCharCodes(bytes.take(200));
            AppLogger.debug('Contenido recibido (primeros 200 chars): $textContent');
          } catch (e) {
            // Ignorar si no es texto
          }

          return null;
        }

        // Validar magic numbers (primeros bytes de la imagen)
        if (bytes.length >= 4) {
          final header = bytes.take(4).toList();
          final isPng = header[0] == 0x89 && header[1] == 0x50 &&
              header[2] == 0x4E && header[3] == 0x47;
          final isGif = header[0] == 0x47 && header[1] == 0x49 && header[2] == 0x46;
          final isJpg = header[0] == 0xFF && header[1] == 0xD8;

          if (!isPng && !isGif && !isJpg) {
            AppLogger.warning(
              'Formato de imagen no reconocido. '
                  'Header: ${header.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
            );
          } else {
            final format = isPng ? 'PNG' : isGif ? 'GIF' : 'JPG';
            AppLogger.success('Formato detectado: $format');
          }
        }

        AppLogger.success(
          'Imagen descargada: ${(bytes.length / 1024).toStringAsFixed(1)} KB',
        );
        return bytes;
      } else {
        AppLogger.error(
          'Error HTTP al descargar imagen',
          'Status code: ${response.statusCode}, Body: ${response.body.substring(0, 100)}',
        );
        return null;
      }
    } catch (e, stackTrace) {
      AppLogger.error('Error al descargar imagen del DACC', e, stackTrace);
      return null;
    }
  }

  /// Descarga el GIF más reciente (latest.gif) - URL CORRECTA
  static Future<Uint8List?> downloadLatestGif() async {
    AppLogger.info('Descargando latest.gif (URL correcta)');
    return downloadImage(AppConstants.daccLatestGif);
  }

  /// Descarga el GIF de la zona sur del DACC
  static Future<Uint8List?> downloadSurGif() async {
    AppLogger.info('Descargando GIF de zona sur');
    return downloadImage(AppConstants.daccSurGif);
  }

  /// Descarga un PNG estático usando el endpoint muestraimagen.php
  ///
  /// [params] Parámetros de la petición (sw, ne, centro, zoom)
  static Future<Uint8List?> downloadStaticPng({
    Map<String, String>? params,
  }) async {
    final queryParams = params ?? AppConstants.daccSanRafaelParams;

    final uri = Uri.parse(AppConstants.daccImageEndpoint).replace(
      queryParameters: queryParams,
    );

    AppLogger.info('Descargando PNG estático con params: $queryParams');
    return downloadImage(uri.toString());
  }

  /// Verifica si el DACC está accesible
  static Future<bool> checkAvailability() async {
    try {
      AppLogger.debug('Verificando disponibilidad del DACC');

      final response = await _httpClient
          .head(Uri.parse(AppConstants.daccBaseUrl))
          .timeout(const Duration(seconds: 10));

      final available = response.statusCode == 200 ||
          response.statusCode == 301 ||
          response.statusCode == 302;

      if (available) {
        AppLogger.success('DACC disponible');
      } else {
        AppLogger.warning('DACC no disponible (${response.statusCode})');
      }

      return available;
    } catch (e) {
      AppLogger.error('Error al verificar disponibilidad del DACC', e);
      return false;
    }
  }

  /// Cierra el cliente HTTP (llamar al cerrar la app)
  static void dispose() {
    _httpClient.close();
    AppLogger.debug('Cliente HTTP del DACC cerrado');
  }
}