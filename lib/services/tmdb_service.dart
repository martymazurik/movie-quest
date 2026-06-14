import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/movie.dart';

const String _kTmdbApiKey = String.fromEnvironment(
  'TMDB_API_KEY',
  defaultValue: 'e66c14358ca106a48327c18346a5ec13',
);

const String _kTmdbImageBase = 'https://image.tmdb.org/t/p/w500';

class TmdbLookupResult {
  final String title;
  final String? description;
  final int? releaseYear;
  final double? externalRating;
  final List<String> actors;
  final String? genre;
  final String? thumbnailUrl;
  final String? trailerUrl;
  final String? howToWatch;
  final String? imdbId;
  final bool isTvSeries;

  TmdbLookupResult({
    required this.title,
    required this.description,
    required this.releaseYear,
    required this.externalRating,
    required this.actors,
    required this.genre,
    required this.thumbnailUrl,
    required this.trailerUrl,
    required this.howToWatch,
    required this.imdbId,
    required this.isTvSeries,
  });
}

class TmdbSearchHit {
  final String id;
  final bool isTv;
  final String title;
  final int? year;
  final String? posterUrl;

  TmdbSearchHit({
    required this.id,
    required this.isTv,
    required this.title,
    required this.year,
    required this.posterUrl,
  });

  String get yearLabel => year == null ? '' : ' ($year)';
  String get typeLabel => isTv ? 'TV' : 'Movie';
}

class TmdbService {
  static final _imdbIdRegex = RegExp(r'tt\d{7,}');
  static final _tmdbMovieIdRegex = RegExp(r'/movie/(\d+)');
  static final _tmdbTvIdRegex = RegExp(r'/tv/(\d+)');

  static bool get isConfigured =>
      _kTmdbApiKey.isNotEmpty &&
      _kTmdbApiKey != 'PASTE_YOUR_TMDB_V3_API_KEY_HERE';

  static Future<TmdbLookupResult> lookup(String input) async {
    if (!isConfigured) {
      throw Exception('TMDB API key is not configured.');
    }
    final raw = input.trim();
    if (raw.isEmpty) {
      throw Exception('Paste an IMDb or TMDB link first.');
    }

    final tvMatch = _tmdbTvIdRegex.firstMatch(raw);
    if (tvMatch != null) {
      return _fetchDetails(id: tvMatch.group(1)!, isTv: true);
    }
    final movieMatch = _tmdbMovieIdRegex.firstMatch(raw);
    if (movieMatch != null) {
      return _fetchDetails(id: movieMatch.group(1)!, isTv: false);
    }

    final imdbMatch = _imdbIdRegex.firstMatch(raw);
    if (imdbMatch == null) {
      throw Exception(
        'Could not find an IMDb ID (tt#######) or TMDB link in the input.',
      );
    }
    final imdbId = imdbMatch.group(0)!;

    final findUri = Uri.parse(
      'https://api.themoviedb.org/3/find/$imdbId'
      '?api_key=$_kTmdbApiKey&external_source=imdb_id',
    );
    final findRes = await http.get(findUri);
    if (findRes.statusCode != 200) {
      throw Exception('TMDB find failed (${findRes.statusCode}).');
    }
    final findData = jsonDecode(findRes.body) as Map<String, dynamic>;
    final tvResults = (findData['tv_results'] as List?) ?? const [];
    final movieResults = (findData['movie_results'] as List?) ?? const [];

    if (tvResults.isNotEmpty) {
      final id = tvResults.first['id'].toString();
      return _fetchDetails(id: id, isTv: true);
    }
    if (movieResults.isNotEmpty) {
      final id = movieResults.first['id'].toString();
      return _fetchDetails(id: id, isTv: false);
    }
    throw Exception('No TMDB match for $imdbId.');
  }

  static Future<List<TmdbSearchHit>> searchMulti(String query) async {
    if (!isConfigured) {
      throw Exception('TMDB API key is not configured.');
    }
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.parse(
      'https://api.themoviedb.org/3/search/multi'
      '?api_key=$_kTmdbApiKey'
      '&query=${Uri.encodeQueryComponent(q)}'
      '&include_adult=false&page=1',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('TMDB search failed (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (data['results'] as List?) ?? const [];
    final hits = <TmdbSearchHit>[];
    for (final r in results) {
      final m = r as Map<String, dynamic>;
      final mediaType = m['media_type'] as String?;
      if (mediaType != 'movie' && mediaType != 'tv') continue;
      final isTv = mediaType == 'tv';
      final title = (isTv ? m['name'] : m['title']) as String? ?? '';
      if (title.isEmpty) continue;
      final dateStr =
          (isTv ? m['first_air_date'] : m['release_date']) as String?;
      final year = (dateStr != null && dateStr.length >= 4)
          ? int.tryParse(dateStr.substring(0, 4))
          : null;
      final poster = m['poster_path'] as String?;
      hits.add(TmdbSearchHit(
        id: m['id'].toString(),
        isTv: isTv,
        title: title,
        year: year,
        posterUrl: (poster == null || poster.isEmpty)
            ? null
            : 'https://image.tmdb.org/t/p/w92$poster',
      ));
      if (hits.length >= 10) break;
    }
    return hits;
  }

  static Future<TmdbLookupResult> fetchDetails({
    required String id,
    required bool isTv,
  }) => _fetchDetails(id: id, isTv: isTv);

  static Future<TmdbLookupResult> _fetchDetails({
    required String id,
    required bool isTv,
  }) async {
    final kind = isTv ? 'tv' : 'movie';
    final uri = Uri.parse(
      'https://api.themoviedb.org/3/$kind/$id'
      '?api_key=$_kTmdbApiKey'
      '&append_to_response=videos,credits,watch/providers,external_ids',
    );
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('TMDB details failed (${res.statusCode}).');
    }
    final d = jsonDecode(res.body) as Map<String, dynamic>;

    final title = (isTv ? d['name'] : d['title']) as String? ?? '';
    final description = d['overview'] as String?;
    final dateStr = (isTv ? d['first_air_date'] : d['release_date']) as String?;
    final year = (dateStr != null && dateStr.length >= 4)
        ? int.tryParse(dateStr.substring(0, 4))
        : null;

    final voteAvg = (d['vote_average'] as num?)?.toDouble();
    final externalRating = voteAvg == null ? null : (voteAvg / 2.0);

    final genresList = (d['genres'] as List?) ?? const [];
    final genre = _mapToImdbGenre(
      genresList.map((g) => (g['name'] ?? '').toString()).toList(),
    );

    final poster = d['poster_path'] as String?;
    final thumbnailUrl = (poster == null || poster.isEmpty)
        ? null
        : '$_kTmdbImageBase$poster';

    final videos = (d['videos']?['results'] as List?) ?? const [];
    final trailerUrl = _pickTrailer(videos);

    final cast = (d['credits']?['cast'] as List?) ?? const [];
    final actors = cast
        .take(5)
        .map((c) => (c['name'] ?? '').toString())
        .where((s) => s.isNotEmpty)
        .toList();

    final providersByRegion =
        (d['watch/providers']?['results'] as Map<String, dynamic>?) ??
            const <String, dynamic>{};
    final howToWatch = _pickHowToWatch(providersByRegion);

    final imdbId = (d['imdb_id'] as String?) ??
        (d['external_ids']?['imdb_id'] as String?);

    return TmdbLookupResult(
      title: title,
      description: description,
      releaseYear: year,
      externalRating: externalRating,
      actors: actors,
      genre: genre,
      thumbnailUrl: thumbnailUrl,
      trailerUrl: trailerUrl,
      howToWatch: howToWatch,
      imdbId: imdbId,
      isTvSeries: isTv,
    );
  }

  static String? _pickHowToWatch(Map<String, dynamic> providersByRegion) {
    final us = providersByRegion['US'] as Map<String, dynamic>?;
    if (us == null) return null;
    const presetAliases = <String, String>{
      'Netflix': 'Netflix',
      'Netflix Standard with Ads': 'Netflix',
      'Amazon Prime Video': 'Prime',
      'Amazon Prime Video with Ads': 'Prime',
      'Amazon Video': 'Prime',
      'Max': 'HBOMax',
      'HBO Max': 'HBOMax',
      'Max Amazon Channel': 'HBOMax',
    };
    final tiers = [
      (us['flatrate'] as List?) ?? const [],
      (us['rent'] as List?) ?? const [],
      (us['buy'] as List?) ?? const [],
    ];
    for (final list in tiers) {
      for (final p in list) {
        final name = (p as Map<String, dynamic>)['provider_name']?.toString();
        if (name == null) continue;
        final mapped = presetAliases[name];
        if (mapped != null) return mapped;
      }
    }
    for (final list in tiers) {
      for (final p in list) {
        final name = (p as Map<String, dynamic>)['provider_name']?.toString();
        if (name == null || name.isEmpty) continue;
        return _cleanProviderName(name);
      }
    }
    return null;
  }

  static String _cleanProviderName(String name) {
    const tidy = <String, String>{
      'Apple TV Plus': 'Apple TV+',
      'Apple TV+': 'Apple TV+',
      'Paramount Plus': 'Paramount+',
      'Paramount+': 'Paramount+',
      'Paramount+ Apple TV Channel': 'Paramount+',
      'Paramount Plus Apple TV Channel': 'Paramount+',
      'Disney Plus': 'Disney+',
      'Disney+': 'Disney+',
      'Peacock Premium': 'Peacock',
      'Peacock Premium Plus': 'Peacock',
    };
    return tidy[name] ?? name;
  }

  static String? _pickTrailer(List videos) {
    Map<String, dynamic>? best;
    for (final v in videos) {
      final m = v as Map<String, dynamic>;
      if (m['site'] != 'YouTube') continue;
      final type = (m['type'] ?? '').toString();
      if (type == 'Trailer' && (best == null || m['official'] == true)) {
        best = m;
      } else if (best == null && (type == 'Teaser' || type == 'Clip')) {
        best = m;
      }
    }
    final key = best?['key'];
    if (key == null) return null;
    return 'https://www.youtube.com/watch?v=$key';
  }

  static String? _mapToImdbGenre(List<String> tmdbGenres) {
    if (tmdbGenres.isEmpty) return null;
    const aliases = <String, String>{
      'Science Fiction': 'Sci-Fi',
      'TV Movie': 'Drama',
      'War & Politics': 'War',
      'Action & Adventure': 'Action',
      'Sci-Fi & Fantasy': 'Sci-Fi',
      'Kids': 'Family',
      'Reality': 'Documentary',
      'News': 'Documentary',
      'Talk': 'Documentary',
      'Soap': 'Drama',
    };
    for (final raw in tmdbGenres) {
      final canonical = aliases[raw] ?? raw;
      if (kImdbGenres.contains(canonical)) return canonical;
    }
    return null;
  }
}
