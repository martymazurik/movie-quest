import 'dart:convert';
import 'package:http/http.dart' as http;

const String _kOmdbApiKey = String.fromEnvironment(
  'OMDB_API_KEY',
  defaultValue: '',
);

class OmdbService {
  static bool get isConfigured => _kOmdbApiKey.isNotEmpty;

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

  static final _wonRegex =
      RegExp(r'^Won\s+(\d+)\s+(.+?)\.?$', caseSensitive: false);
  static final _nominatedRegex =
      RegExp(r'^Nominated for\s+(\d+)\s+(.+?)\.?$', caseSensitive: false);

  static List<String> _parseAwards(String raw) {
    final sentences = raw
        .split(RegExp(r'\.\s+|\.$'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    final picks = <String>[];
    for (final s in sentences) {
      final won = _wonRegex.firstMatch(s);
      if (won != null) {
        final name = _canonicalAwardName(won.group(2)!);
        if (name != null) picks.add('$name (winner)');
        continue;
      }
      final nom = _nominatedRegex.firstMatch(s);
      if (nom != null) {
        final name = _canonicalAwardName(nom.group(2)!);
        if (name != null) picks.add('$name (nominee)');
      }
    }
    final seen = <String>{};
    final unique = <String>[];
    for (final p in picks) {
      if (seen.add(p)) unique.add(p);
      if (unique.length == 2) break;
    }
    return unique;
  }

  static String? _canonicalAwardName(String raw) {
    var s = raw.trim();
    if (s.toLowerCase().endsWith(' awards')) {
      s = s.substring(0, s.length - 1);
    } else if (s.toLowerCase().endsWith('s') && !s.toLowerCase().endsWith('ss')) {
      s = s.substring(0, s.length - 1);
    }
    final lower = s.toLowerCase();
    const known = <String, String>{
      'oscar': 'Academy Award',
      'academy award': 'Academy Award',
      'golden globe': 'Golden Globe',
      'primetime emmy': 'Primetime Emmy',
      'emmy': 'Emmy',
      'bafta award': 'BAFTA',
      'bafta film award': 'BAFTA',
      'bafta': 'BAFTA',
      'sag award': 'SAG Award',
      'screen actors guild award': 'SAG Award',
      'critics choice award': 'Critics Choice Award',
      'sundance film festival award': 'Sundance',
      'cannes film festival award': 'Cannes',
      'palme d\'or': 'Palme d\'Or',
    };
    return known[lower];
  }
}
