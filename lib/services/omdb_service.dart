import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kOmdbApiKey = String.fromEnvironment(
  'OMDB_API_KEY',
  defaultValue: '83f85f58',
);

class OmdbService {
  static bool get isConfigured =>
      _kOmdbApiKey.isNotEmpty && _kOmdbApiKey != 'PASTE_YOUR_OMDB_KEY_HERE';

  static Future<List<String>> fetchTopAwards(String imdbId) async {
    if (!isConfigured) return const [];
    if (imdbId.isEmpty) return const [];
    final uri = Uri.parse(
      'https://www.omdbapi.com/?apikey=$_kOmdbApiKey&i=$imdbId',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('OMDb HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (data['Response'] == 'False') {
      throw Exception('OMDb: ${data['Error'] ?? 'unknown error'}');
    }
    final raw = (data['Awards'] as String?)?.trim() ?? '';
    if (raw.isEmpty || raw == 'N/A') return const [];
    return _parseAwards(raw);
  }

  static List<String> _parseAwards(String raw) {
    final sentences = raw
        .split(RegExp(r'\.\s+|\.$'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final wins = <String>[];
    final summaries = <String>[];
    for (final s in sentences) {
      final lower = s.toLowerCase();
      if (lower.startsWith('won') || lower.startsWith('nominated for')) {
        wins.add(s);
      } else {
        summaries.add(s);
      }
    }
    final picks = <String>[...wins, ...summaries];
    return picks.take(2).toList();
  }
}
