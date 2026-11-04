import 'dart:ui';

class DetectionItem {
  final String label;
  final double confidence;
  final Rect box; // koordinat dalam piksel gambar asli

  const DetectionItem({
    required this.label,
    required this.confidence,
    required this.box,
  });
}