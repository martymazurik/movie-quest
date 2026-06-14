import 'dart:convert';
import 'package:http/http.dart' as http;

class WikidataService {
  static Future<List<String>> fetchTopAwards(String imdbId) async {
    if (imdbId.isEmpty) return const [];
    final query = '''
SELECT ?awardLabel ?winner WHERE {
  ?film wdt:P345 "$imdbId".
  {
    ?film wdt:P166 ?award.
    BIND(true AS ?winner)
  } UNION {
    ?film wdt:P1411 ?award.
    BIND(false AS ?winner)
  }
  SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
}
LIMIT 30
''';
    final uri = Uri.parse(
      'https://query.wikidata.org/sparql'
      '?format=json&query=${Uri.encodeQueryComponent(query)}',
    );
    final res = await http.get(
      uri,
      headers: {'Accept': 'application/sparql-results+json'},
    );
    if (res.statusCode != 200) {
      throw Exception('Wikidata HTTP ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final rows = (data['results']?['bindings'] as List?) ?? const [];

    final scored = <_ScoredAward>[];
    for (final r in rows) {
      final row = r as Map<String, dynamic>;
      final label = (row['awardLabel']?['value'] as String?)?.trim();
      if (label == null || label.isEmpty) continue;
      final winner = row['winner']?['value'] == 'true';
      scored.add(_ScoredAward(
        label: label,
        winner: winner,
        prestige: _prestigeScore(label),
      ));
    }
    scored.sort((a, b) {
      if (a.prestige != b.prestige) return b.prestige.compareTo(a.prestige);
      if (a.winner != b.winner) return a.winner ? -1 : 1;
      return a.label.compareTo(b.label);
    });

    final seen = <String>{};
    final picks = <String>[];
    for (final s in scored) {
      final entry = '${s.label} (${s.winner ? 'winner' : 'nominee'})';
      if (seen.add(entry)) picks.add(entry);
      if (picks.length == 2) break;
    }
    return picks;
  }

  static int _prestigeScore(String label) {
    final l = label.toLowerCase();
    if (l.contains('academy award')) return 100;
    if (l.contains('golden globe')) return 90;
    if (l.contains('bafta')) return 85;
    if (l.contains('primetime emmy')) return 80;
    if (l.contains('palme')) return 80;
    if (l.contains('cannes')) return 75;
    if (l.contains('sundance')) return 75;
    if (l.contains('venice') || l.contains('golden lion')) return 75;
    if (l.contains('berlin') || l.contains('golden bear')) return 75;
    if (l.contains('sag award') || l.contains('screen actors guild')) {
      return 70;
    }
    if (l.contains('critics choice')) return 65;
    if (l.contains('emmy')) return 60;
    if (l.contains('razzie')) return 50;
    return 10;
  }
}

class _ScoredAward {
  final String label;
  final bool winner;
  final int prestige;
  _ScoredAward({
    required this.label,
    required this.winner,
    required this.prestige,
  });
}
