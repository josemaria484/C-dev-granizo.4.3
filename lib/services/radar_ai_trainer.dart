import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'synthetic_radar_service.dart';

class RadarAITrainer {
  static const String _trainingDir = 'radar_training';

  static Future<void> saveTrainingImage(
      Uint8List pngBytes,
      List<StormNucleus> nuclei,
      DateTime timestamp,
      ) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final trainingPath = '${dir.path}/$_trainingDir';

      final trainingDir = Directory(trainingPath);
      if (!await trainingDir.exists()) {
        await trainingDir.create(recursive: true);
      }

      final fileName = 'radar_${timestamp.millisecondsSinceEpoch}_'
          'n${nuclei.length}_'
          'max${nuclei.isNotEmpty ? nuclei.first.maxDbz.toInt() : 0}.png';

      final file = File('$trainingPath/$fileName');
      await file.writeAsBytes(pngBytes);

      final metaFile = File('$trainingPath/$fileName.json');
      final metadata = _generateMetadata(nuclei, timestamp);
      await metaFile.writeAsString(metadata);

      // ignore: avoid_print
      print('✅ Training image saved: $fileName');
    } catch (e) {
      // ignore: avoid_print
      print('❌ Error saving training image: $e');
    }
  }

  static String _generateMetadata(
      List<StormNucleus> nuclei,
      DateTime timestamp,
      ) {
    final nucleiJson = nuclei
        .map((n) => {
      'lat': n.center.latitude,
      'lon': n.center.longitude,
      'dbz': n.maxDbz,
      'type': n.type.toString(),
      'radius_km': n.radiusKm,
    })
        .toList();

    return '''
{
  "timestamp": "${timestamp.toIso8601String()}",
  "nuclei_count": ${nuclei.length},
  "nuclei": $nucleiJson
}
''';
  }

  static Future<Map<String, dynamic>> getTrainingStats() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final trainingPath = '${dir.path}/$_trainingDir';
      final trainingDir = Directory(trainingPath);

      if (!await trainingDir.exists()) {
        return {'count': 0, 'size_mb': 0};
      }

      final files = trainingDir.listSync().where((f) => f.path.endsWith('.png')).toList();
      int totalSize = 0;
      for (final f in files) {
        totalSize += await File(f.path).length();
      }

      return {'count': files.length, 'size_mb': (totalSize / (1024 * 1024)).toStringAsFixed(2)};
    } catch (e) {
      return {'count': 0, 'size_mb': 0, 'error': e.toString()};
    }
  }
}
