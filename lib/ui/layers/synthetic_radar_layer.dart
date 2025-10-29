import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../../services/synthetic_radar_service.dart';

class SyntheticRadarLayer extends StatelessWidget {
  final List<SyntheticRadarPoint> radarPoints;

  const SyntheticRadarLayer({Key? key, required this.radarPoints}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (radarPoints.isEmpty) return const SizedBox.shrink();

    return CircleLayer(
      circles: radarPoints.map((p) {
        return CircleMarker(
          point: p.coordinate,
          radius: 5.0,
          color: p.color,
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
          useRadiusInMeter: false,
        );
      }).toList(),
    );
  }
}
