import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../main.dart';
import '../chatbot/gemini_service.dart';
import 'detection_model.dart';
import 'detection_service.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({super.key});

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final ImagePicker _picker = ImagePicker();
  final DetectionService _service = DetectionService();
  final GeminiService _gemini = GeminiService();

  File? _image;
  Size? _imageSize;

  // Hasil YOLO
  List<DetectionItem> _results = [];
  bool _loading = false;
  bool _detected = false;

  // Hasil Gemini
  bool _aiLoading = false;
  String? _aiResult;

  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _mimeOf(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.png')) return 'image/png';
    if (p.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final decoded = await decodeImageFromList(bytes);

      setState(() {
        _image = File(picked.path);
        _imageSize =
            Size(decoded.width.toDouble(), decoded.height.toDouble());
        _results = [];
        _detected = false;
        _aiResult = null;
      });
    } catch (e) {
      _toast('Gagal mengambil gambar: $e');
    }
  }

  Future<void> _runDetection() async {
    if (_image == null || _imageSize == null) return;
    if (!_mobile) {
      _toast('Deteksi YOLO hanya jalan di Android atau iOS.');
      return;
    }

    setState(() => _loading = true);
    try {
      final bytes = await _image!.readAsBytes();
      final res = await _service.detect(bytes, _imageSize!);
      setState(() {
        _results = res;
        _detected = true;
      });
    } catch (e) {
      _toast('Deteksi gagal: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _runAi() async {
    if (_image == null) return;

    setState(() {
      _aiLoading = true;
      _aiResult = null;
    });
    try {
      final bytes = await _image!.readAsBytes();
      final text = await _gemini.describeImage(bytes, _mimeOf(_image!.path));
      if (!mounted) return;
      setState(() => _aiResult = text);
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildPreview(),
              _buildButtons(),
              _buildYoloResults(),
              _buildAiResult(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 62,
      width: double.infinity,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1B2230)),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'Deteksi Object',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2230),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 24, 13, 0),
      child: Container(
        height: 380,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: _image == null || _imageSize == null
            ? const Center(
                child: Text(
                  'Belum ada gambar',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              )
            : Center(
                child: AspectRatio(
                  aspectRatio: _imageSize!.width / _imageSize!.height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.file(_image!, fit: BoxFit.fill),
                      CustomPaint(
                        painter: BoxPainter(_results, _imageSize!),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildButtons() {
    final busy = _loading || _aiLoading;
    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 20, 13, 0),
      child: Column(
        children: [
          Row(
            children: [
              if (_mobile) ...[
                Expanded(
                  child: _PickButton(
                    icon: Icons.photo_camera_outlined,
                    label: 'Kamera',
                    bg: AppColors.pink,
                    onTap: () => _pickImage(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Galeri',
                  bg: AppColors.lavender,
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.search,
                  label: _loading ? 'Mendeteksi...' : 'Deteksi',
                  bg: Colors.white,
                  onTap: busy || _image == null ? () {} : _runDetection,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  icon: Icons.auto_awesome,
                  label: _aiLoading ? 'Mengenali...' : 'Kenali AI',
                  bg: Colors.white,
                  onTap: busy || _image == null ? () {} : _runAi,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYoloResults() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (!_detected) return const SizedBox.shrink();

    if (_results.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(13, 24, 13, 0),
        child: Text(
          'Tidak ada objek terdeteksi. Coba tombol Kenali AI.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 24, 13, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_results.length} objek terdeteksi',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1B2230),
            ),
          ),
          const SizedBox(height: 10),
          for (final r in _results) _DetailCard(item: r, service: _service),
        ],
      ),
    );
  }

  Widget _buildAiResult() {
    if (_aiLoading) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    if (_aiResult == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 24, 13, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.lavender,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: AppColors.purple),
                SizedBox(width: 6),
                Text(
                  'Hasil Kenali AI',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              _aiResult!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BoxPainter extends CustomPainter {
  final List<DetectionItem> items;
  final Size imageSize;

  BoxPainter(this.items, this.imageSize);

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / imageSize.width;
    final sy = size.height / imageSize.height;

    for (final item in items) {
      final color = HSVColor.fromAHSV(
        1,
        (item.label.hashCode * 37 % 360).toDouble(),
        0.8,
        1,
      ).toColor();

      final rect = Rect.fromLTRB(
        item.box.left * sx,
        item.box.top * sy,
        item.box.right * sx,
        item.box.bottom * sy,
      );

      canvas.drawRect(
        rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${item.label} ${(item.confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelTop = (rect.top - tp.height - 4).clamp(0.0, size.height);
      canvas.drawRect(
        Rect.fromLTWH(rect.left, labelTop, tp.width + 8, tp.height + 4),
        Paint()..color = color,
      );
      tp.paint(canvas, Offset(rect.left + 4, labelTop + 2));
    }
  }

  @override
  bool shouldRepaint(covariant BoxPainter old) =>
      old.items != items || old.imageSize != imageSize;
}

class _DetailCard extends StatelessWidget {
  final DetectionItem item;
  final DetectionService service;

  const _DetailCard({required this.item, required this.service});

  @override
  Widget build(BuildContext context) {
    final info = service.infoFor(item.label);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info?.nama ?? item.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B1B1B),
                  ),
                ),
              ),
              Text(
                '${(item.confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF444444)),
          ),
          const SizedBox(height: 6),
          Text(
            info?.deskripsi ?? 'Detail belum tersedia untuk objek ini.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF1B1B1B)),
          ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final VoidCallback onTap;

  const _PickButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF1B1B1B)),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF1B1B1B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}