import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kAnthropicApiKey = String.fromEnvironment(
  'ANTHROPIC_API_KEY',
  defaultValue: '',
);

const String _kModel = 'claude-haiku-4-5-20251001';

const String _kSystemPrompt = '''
You are a film/TV awards expert. Given a title and year, list up to 2 of the most notable real-world award nominations or wins.

Rules:
- Return ONLY a comma-separated list, no preamble or explanation.
- Format each entry exactly as: "<Award Name> (winner)" or "<Award Name> (nominee)".
- Prefer wins over nominations when both exist.
- Prefer prestige (Academy Award, Golden Globe, BAFTA, Primetime Emmy, Cannes, Razzie, SAG Award, Critics Choice, Satellite Award) over obscure regional awards.
- Use canonical award names. If a specific category is well known, include it ("Academy Award for Best Picture", "Razzie for Worst Screen Couple").
- If you are not CERTAIN the title received the award, do NOT include it. Better to return less than to invent.
- If the title received no notable awards, output the single token: NONE
''';

class LlmAwardsService {
  static bool get isConfigured => _kAnthropicApiKey.isNotEmpty;

  static Future<List<String>> fetchTopAwards({
    required String title,
    int? year,
    required bool isTv,
  }) async {
    if (!isConfigured) return const [];
    if (title.trim().isEmpty) return const [];
    final mediaKind = isTv ? 'TV series' : 'film';
    final yearStr = year == null ? '' : ' ($year)';
    final userMsg = '$mediaKind: "$title"$yearStr';

    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'x-api-key': _kAnthropicApiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': _kModel,
        'max_tokens': 200,
        'temperature': 0,
        'system': _kSystemPrompt,
        'messages': [
          {'role': 'user', 'content': userMsg},
        ],
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Claude HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final blocks = (data['content'] as List?) ?? const [];
    final text = blocks
        .map((b) => (b as Map<String, dynamic>)['text']?.toString() ?? '')
        .join()
        .trim();

    if (text.isEmpty || text.toUpperCase() == 'NONE') return const [];

    final parts = text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.toUpperCase() != 'NONE')
        .toList();

    return parts.take(2).toList();
  }
}
