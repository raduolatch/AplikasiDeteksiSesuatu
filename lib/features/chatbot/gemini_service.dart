import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import 'message_model.dart';

class GeminiService {
  // Pakai nama model yang sudah berhasil di akunmu
  static const String model = 'gemini-3.5-flash-lite';

  static const String _systemPrompt =
      'Kamu adalah asisten AI di aplikasi Deteksi Object. '
      'Jawab dalam Bahasa Indonesia dengan singkat, jelas, dan ramah. '
      'Kamu bisa membantu menjelaskan benda, fungsi, dan cara kerja deteksi objek.';

  static const String _imagePrompt =
      'Kenali benda utama pada foto ini. '
      'Jawab dalam Bahasa Indonesia, singkat dan jelas, '
      'tanpa format markdown (jangan pakai tanda * atau #). '
      'Gunakan format persis seperti ini:\n'
      'Nama: ...\n'
      'Kategori: ...\n'
      'Deskripsi: ...\n'
      'Kegunaan: ...\n'
      'Catatan: ... (isi hanya jika ada merek atau teks yang terlihat jelas '
      'pada foto, jika tidak tulis "-")\n'
      'Jika benda tidak jelas, katakan apa adanya dan jangan menebak merek.';

  // Chat teks
  Future<String> send(List<ChatMessage> history) async {
    // Kirim maksimal 20 pesan terakhir, dan mulai dari pesan user
    var recent = history.length > 20
        ? history.sublist(history.length - 20)
        : history;
    recent = recent.skipWhile((m) => !m.isUser).toList();

    return _post({
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt},
        ],
      },
      'contents': [
        for (final m in recent)
          {
            'role': m.isUser ? 'user' : 'model',
            'parts': [
              {'text': m.text},
            ],
          },
      ],
    }, timeout: 30);
  }

  // Kenali benda dari foto
  Future<String> describeImage(Uint8List bytes, String mimeType) {
    return _post({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Encode(bytes),
              },
            },
            {'text': _imagePrompt},
          ],
        },
      ],
    }, timeout: 60);
  }

  Future<String> _post(Map<String, dynamic> payload,
      {required int timeout}) async {
    final key = dotenv.env['GEMINI_API_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('API key belum diisi di file .env');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
    );

    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': key,
          },
          body: jsonEncode(payload),
        )
        .timeout(Duration(seconds: timeout));

    final data = jsonDecode(utf8.decode(res.bodyBytes));

    if (res.statusCode != 200) {
      String? msg;
      if (data is Map && data['error'] is Map) {
        msg = data['error']['message']?.toString();
      }
      throw Exception(msg ?? 'Terjadi kesalahan (kode ${res.statusCode})');
    }

    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('AI tidak memberi jawaban. Coba foto atau pertanyaan lain.');
    }

    final parts = candidates[0]['content']?['parts'] as List?;
    final text = parts?.map((p) => p['text'] ?? '').join() ?? '';
    if (text.trim().isEmpty) {
      throw Exception('Jawaban AI kosong.');
    }
    return text.trim();
  }
}