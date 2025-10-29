import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../services/synthetic_radar_service.dart';

class SyntheticRadarPainterLayer extends StatelessWidget {
  final List<SyntheticRadarPoint> radarPoints;
  final MapCamera camera;
  const SyntheticRadarPainterLayer({Key? key, required this.radarPoints, required this.camera}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (radarPoints.isEmpty) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SyntheticRadarPainter(radarPoints: radarPoints, camera: camera),
      child: Container(),
    );
  }
}

class _SyntheticRadarPainter extends CustomPainter {
  final List<SyntheticRadarPoint> radarPoints;
  final MapCamera camera;

  _SyntheticRadarPainter({required this.radarPoints, required this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in radarPoints) {
      final pt = camera.latLngToScreenPoint(p.coordinate);
      if (pt.x >= -20 && pt.x <= size.width + 20 && pt.y >= -20 && pt.y <= size.height + 20) {
        final paint = Paint()..color = p.color..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(pt.x, pt.y), 3.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SyntheticRadarPainter old) =>
      radarPoints != old.radarPoints || camera != old.camera;
}
