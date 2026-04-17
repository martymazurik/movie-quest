import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/movie.dart';

class MovieService {
  static final _col = FirebaseFirestore.instance.collection('movies');

  static Stream<List<Movie>> watchAll() {
    return _col
        .orderBy('enteredDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(Movie.fromFirestore).toList());
  }

  static Future<void> add(Movie movie) async {
    await _col.add(movie.toFirestore(isNew: true));
  }

  static Future<void> update(Movie movie) async {
    if (movie.id == null) {
      throw ArgumentError('Cannot update movie without id');
    }
    await _col.doc(movie.id).update(movie.toFirestore());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
