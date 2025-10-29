import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../services/synthetic_radar_service.dart';

class OptimizedRadarLayer extends StatelessWidget {
  final List<SyntheticRadarPoint> radarPoints;

  const OptimizedRadarLayer({Key? key, required this.radarPoints}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (radarPoints.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _RadarPainter(radarPoints: radarPoints),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final List<SyntheticRadarPoint> radarPoints;

  _RadarPainter({required this.radarPoints});

  @override
  void paint(Canvas canvas, Size size) {
    final pointsByColor = <Color, List<Offset>>{};

    for (final p in radarPoints) {
      // Aproximación rápida; en producción usar MapCamera.latLngToScreenPoint
      final x = ((p.coordinate.longitude + 70.5) / 3.5) * size.width;
      final y = ((37.5 - p.coordinate.latitude) / 6.0) * size.height;

      if (x >= 0 && x <= size.width && y >= 0 && y <= size.height) {
        pointsByColor.putIfAbsent(p.color, () => []).add(Offset(x, y));
      }
    }

    for (final entry in pointsByColor.entries) {
      final paint = Paint()..color = entry.key..style = PaintingStyle.fill;
      for (final o in entry.value) {
        canvas.drawCircle(o, 4.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      radarPoints != oldDelegate.radarPoints;
}
