import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import 'detection_model.dart';

class ObjectInfo {
  final String nama;
  final String deskripsi;
  const ObjectInfo(this.nama, this.deskripsi);
}

class DetectionService {
  YOLO? _yolo;
  Map<String, ObjectInfo>? _details;

  static const double minConfidence = 0.25;

  Future<void> _ensureLoaded() async {
    if (_yolo == null) {
      final yolo = YOLO(modelPath: 'yolo26n');
      await yolo.loadModel();
      _yolo = yolo;
    }
    if (_details == null) {
      final text = await rootBundle.loadString('assets/data/object_details.json');
      final map = jsonDecode(text) as Map<String, dynamic>;
      _details = map.map((k, v) => MapEntry(
            k,
            ObjectInfo(v['nama'] as String, v['deskripsi'] as String),
          ));
    }
  }

  ObjectInfo? infoFor(String label) => _details?[label];

  Future<List<DetectionItem>> detect(Uint8List bytes, Size imageSize) async {
    await _ensureLoaded();
    final raw = await _yolo!.predict(bytes);

    // Cetak hasil mentah untuk memeriksa format keluaran paket
    debugPrint('RAW YOLO RESULT: $raw');

    return _parse(raw, imageSize)
        .where((d) => d.confidence >= minConfidence)
        .toList()
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
  }

  List<DetectionItem> _parse(dynamic raw, Size size) {
    dynamic list = raw;
    if (raw is Map) {
      list = raw['boxes'] ?? raw['detections'] ?? raw['results'];
    }
    if (list is! List) return [];

    final items = <DetectionItem>[];
    for (final b in list) {
      if (b is! Map) continue;

      final label = (b['className'] ?? b['class'] ?? b['label'] ?? '').toString();
      final conf = (b['confidence'] as num?)?.toDouble() ?? 0.0;

      double? l, t, r, bt;
      final bb = b['boundingBox'] ?? b['box'];
      if (b['x1'] != null) {
        l = (b['x1'] as num).toDouble();
        t = (b['y1'] as num).toDouble();
        r = (b['x2'] as num).toDouble();
        bt = (b['y2'] as num).toDouble();
      } else if (bb is Map) {
        l = (bb['left'] as num?)?.toDouble();
        t = (bb['top'] as num?)?.toDouble();
        r = (bb['right'] as num?)?.toDouble();
        bt = (bb['bottom'] as num?)?.toDouble();
      }
      if (l == null || t == null || r == null || bt == null) continue;

      // Jika koordinat ternormalisasi (0..1), ubah ke piksel
      final normalized = r <= 1.0 && bt <= 1.0;
      if (normalized) {
        l *= size.width;
        r *= size.width;
        t *= size.height;
        bt *= size.height;
      }

      items.add(DetectionItem(
        label: label,
        confidence: conf,
        box: Rect.fromLTRB(l, t, r, bt),
      ));
    }
    return items;
  }
}