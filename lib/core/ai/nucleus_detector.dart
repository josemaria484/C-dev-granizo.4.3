// lib/core/ai/nucleus_detector.dart

import 'package:image/image.dart' as img;
import '../../utils/logger.dart';
import '../../data/models/storm_nucleus.dart';
import 'color_mapper.dart';
import 'geolocation_engine.dart';

/// Clase interna para representar un píxel durante clustering
class _ClusterPixel {
  final int x, y, dbz;
  _ClusterPixel(this.x, this.y, this.dbz);
}

/// Detector de núcleos de tormenta mediante clustering de píxeles
class NucleusDetector {
  final GeolocationEngine geoEngine;

  NucleusDetector(this.geoEngine);

  /// Detecta núcleos de tormenta en una imagen del radar
  ///
  /// [radarImage] Imagen PNG del DACC
  /// [minDbz] Umbral mínimo de dBZ para considerar (default: 30)
  /// [minPixels] Mínimo de píxeles para formar un núcleo (default: 10)
  Future<List<StormNucleus>> detectNuclei(
      img.Image radarImage, {
        int minDbz = 30,
        int minPixels = 10,
      }) async {
    AppLogger.start('Detectando núcleos de tormenta (umbral: $minDbz dBZ)');

    final width = radarImage.width;
    final height = radarImage.height;

    // Matriz de píxeles visitados
    final visited = List.generate(
      height,
          (_) => List.filled(width, false),
    );

    final nuclei = <StormNucleus>[];
    int nucleusId = 0;

    // Recorrer toda la imagen
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (visited[y][x]) continue;

        // Obtener píxel y estimar dBZ
        final pixel = radarImage.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final dbz = ColorMapper.estimateDBZ(r, g, b);

        // Si supera el umbral, iniciar clustering
        if (dbz >= minDbz && dbz != -1) {
          final cluster = _floodFill(
            radarImage,
            visited,
            x,
            y,
            minDbz,
          );

          // Si el cluster es suficientemente grande, crear núcleo
          if (cluster.length >= minPixels) {
            final nucleus = _createNucleusFromCluster(
              cluster,
              'nucleus_$nucleusId',
            );
            nuclei.add(nucleus);
            nucleusId++;
          }
        }
      }
    }

    AppLogger.success('Núcleos detectados: ${nuclei.length}');

    for (final nucleus in nuclei) {
      AppLogger.info('  → $nucleus');
    }

    return nuclei;
  }

  /// Flood fill para encontrar píxeles contiguos del mismo núcleo
  List<_ClusterPixel> _floodFill(
      img.Image image,
      List<List<bool>> visited,
      int startX,
      int startY,
      int minDbz,
      ) {
    final cluster = <_ClusterPixel>[];
    final stack = <(int, int)>[(startX, startY)];
    final width = image.width;
    final height = image.height;

    while (stack.isNotEmpty) {
      final (x, y) = stack.removeLast();

      // Verificar límites
      if (x < 0 || x >= width || y < 0 || y >= height) continue;
      if (visited[y][x]) continue;

      // Obtener dBZ del píxel
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();
      final dbz = ColorMapper.estimateDBZ(r, g, b);

      // Si no cumple umbral, ignorar
      if (dbz < minDbz || dbz == -1) continue;

      // Marcar como visitado y agregar al cluster
      visited[y][x] = true;
      cluster.add(_ClusterPixel(x, y, dbz));

      // Agregar vecinos (4-conectividad: arriba, abajo, izq, der)
      stack.addAll([
        (x + 1, y),
        (x - 1, y),
        (x, y + 1),
        (x, y - 1),
      ]);
    }

    return cluster;
  }

  /// Crea un StormNucleus a partir de un cluster de píxeles
  StormNucleus _createNucleusFromCluster(
      List<_ClusterPixel> cluster,
      String id,
      ) {
    // Calcular centroide
    double sumX = 0, sumY = 0;
    int maxDbz = 0;

    for (final pixel in cluster) {
      sumX += pixel.x;
      sumY += pixel.y;
      if (pixel.dbz > maxDbz) {
        maxDbz = pixel.dbz;
      }
    }

    final centerX = sumX / cluster.length;
    final centerY = sumY / cluster.length;

    // Convertir centroide de píxel a LatLng
    final position = geoEngine.pixelToLatLng(centerX, centerY);

    // Estimar radio
    final radiusKm = geoEngine.estimateRadiusKm(cluster.length);

    return StormNucleus(
      id: id,
      position: position,
      maxDbz: maxDbz,
      radiusKm: radiusKm,
      pixelCount: cluster.length,
    );
  }

  /// Detecta núcleos con múltiples umbrales (para análisis detallado)
  Future<Map<String, List<StormNucleus>>> detectNucleiByLevel(
      img.Image radarImage,
      ) async {
    AppLogger.start('Detectando núcleos por nivel de intensidad');

    final results = <String, List<StormNucleus>>{};

    // Nivel Rojo (≥55 dBZ)
    results['red'] = await detectNuclei(radarImage, minDbz: 55);

    // Nivel Naranja (≥45 dBZ)
    results['orange'] = await detectNuclei(radarImage, minDbz: 45);

    // Nivel Amarillo (≥30 dBZ)
    results['yellow'] = await detectNuclei(radarImage, minDbz: 30);

    AppLogger.success(
      'Núcleos por nivel: '
          'Rojo=${results['red']!.length}, '
          'Naranja=${results['orange']!.length}, '
          'Amarillo=${results['yellow']!.length}',
    );

    return results;
  }
}