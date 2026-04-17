import 'package:cloud_firestore/cloud_firestore.dart';

class Movie {
  final String? id;
  final String title;
  final String description;
  final List<String> actors;
  final int? releaseYear;
  final double externalRating;
  final int ourRating;
  final List<String> awards;
  final DateTime? watchDate;
  final String? trailerUrl;
  final String? thumbnailUrl;
  final String? howToWatch;
  final String enteredBy;
  final DateTime? enteredDate;

  Movie({
    this.id,
    required this.title,
    required this.description,
    required this.actors,
    required this.releaseYear,
    required this.externalRating,
    required this.ourRating,
    required this.awards,
    required this.watchDate,
    required this.trailerUrl,
    required this.thumbnailUrl,
    required this.howToWatch,
    required this.enteredBy,
    this.enteredDate,
  });

  factory Movie.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return Movie(
      id: doc.id,
      title: (d['title'] ?? '') as String,
      description: (d['description'] ?? '') as String,
      actors: List<String>.from(d['actors'] ?? const []),
      releaseYear: (d['releaseYear'] as num?)?.toInt(),
      externalRating: (d['externalRating'] as num?)?.toDouble() ?? 0.0,
      ourRating: (d['ourRating'] as num?)?.toInt() ?? 0,
      awards: List<String>.from(d['awards'] ?? const []),
      watchDate: (d['watchDate'] as Timestamp?)?.toDate(),
      trailerUrl: d['trailerUrl'] as String?,
      thumbnailUrl: d['thumbnailUrl'] as String?,
      howToWatch: d['howToWatch'] as String?,
      enteredBy: (d['enteredBy'] ?? '') as String,
      enteredDate: (d['enteredDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore({bool isNew = false}) {
    return {
      'title': title,
      'description': description,
      'actors': actors,
      'releaseYear': releaseYear,
      'externalRating': externalRating,
      'ourRating': ourRating,
      'awards': awards,
      'watchDate': watchDate == null ? null : Timestamp.fromDate(watchDate!),
      'trailerUrl': trailerUrl,
      'thumbnailUrl': thumbnailUrl,
      'howToWatch': howToWatch,
      'enteredBy': enteredBy,
      if (isNew) 'enteredDate': FieldValue.serverTimestamp(),
    };
  }

  Movie copyWith({
    String? title,
    String? description,
    List<String>? actors,
    int? releaseYear,
    double? externalRating,
    int? ourRating,
    List<String>? awards,
    DateTime? watchDate,
    String? trailerUrl,
    String? thumbnailUrl,
    String? howToWatch,
    String? enteredBy,
  }) {
    return Movie(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      actors: actors ?? this.actors,
      releaseYear: releaseYear ?? this.releaseYear,
      externalRating: externalRating ?? this.externalRating,
      ourRating: ourRating ?? this.ourRating,
      awards: awards ?? this.awards,
      watchDate: watchDate ?? this.watchDate,
      trailerUrl: trailerUrl ?? this.trailerUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      howToWatch: howToWatch ?? this.howToWatch,
      enteredBy: enteredBy ?? this.enteredBy,
      enteredDate: enteredDate,
    );
  }
}
