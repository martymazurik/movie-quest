import 'package:flutter/material.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/user_service.dart';
import '../widgets/movie_card.dart';
import 'movie_form_screen.dart';
import 'name_prompt_screen.dart';

enum _SortMode { recent, title, ourRating, externalRating, releaseYear }

class MovieListScreen extends StatefulWidget {
  const MovieListScreen({super.key});

  @override
  State<MovieListScreen> createState() => _MovieListScreenState();
}

class _MovieListScreenState extends State<MovieListScreen> {
  final _searchController = TextEditingController();
  String _query = '';
  _SortMode _sort = _SortMode.recent;
  bool _hideWatched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Movie> _filterAndSort(List<Movie> movies) {
    final q = _query.trim().toLowerCase();
    Iterable<Movie> out = movies;
    if (_hideWatched) {
      out = out.where((m) => m.watchDate == null);
    }
    if (q.isNotEmpty) {
      out = out.where((m) {
        if (m.title.toLowerCase().contains(q)) return true;
        if (m.description.toLowerCase().contains(q)) return true;
        if (m.actors.any((a) => a.toLowerCase().contains(q))) return true;
        if (m.awards.any((a) => a.toLowerCase().contains(q))) return true;
        if (m.enteredBy.toLowerCase().contains(q)) return true;
        return false;
      });
    }
    final list = out.toList();
    switch (_sort) {
      case _SortMode.recent:
        list.sort((a, b) {
          final ad = a.enteredDate?.millisecondsSinceEpoch ?? 0;
          final bd = b.enteredDate?.millisecondsSinceEpoch ?? 0;
          return bd.compareTo(ad);
        });
      case _SortMode.title:
        list.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _SortMode.ourRating:
        list.sort((a, b) => b.ourRating.compareTo(a.ourRating));
      case _SortMode.externalRating:
        list.sort((a, b) => b.externalRating.compareTo(a.externalRating));
      case _SortMode.releaseYear:
        list.sort((a, b) =>
            (b.releaseYear ?? 0).compareTo(a.releaseYear ?? 0));
    }
    return list;
  }

  Future<void> _openForm({Movie? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MovieFormScreen(existing: existing),
      ),
    );
  }

  Future<void> _changeName() async {
    await UserService.clearName();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => NamePromptScreen(
          onSaved: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MovieListScreen()),
            );
          },
        ),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MovieQuest'),
        actions: [
          IconButton(
            icon: Icon(
              _hideWatched ? Icons.visibility_off : Icons.visibility,
            ),
            tooltip: _hideWatched ? 'Showing unwatched only' : 'Hide watched',
            onPressed: () => setState(() => _hideWatched = !_hideWatched),
          ),
          PopupMenuButton<_SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            initialValue: _sort,
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _SortMode.recent, child: Text('Recently added')),
              PopupMenuItem(value: _SortMode.title, child: Text('Title A→Z')),
              PopupMenuItem(value: _SortMode.ourRating, child: Text('Our rating')),
              PopupMenuItem(value: _SortMode.externalRating, child: Text('External rating')),
              PopupMenuItem(value: _SortMode.releaseYear, child: Text('Release year')),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'change_name') _changeName();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'change_name', child: Text('Change name')),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search title, actor, description…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add movie'),
      ),
      body: StreamBuilder<List<Movie>>(
        stream: MovieService.watchAll(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error loading movies:\n${snap.error}',
                    textAlign: TextAlign.center),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final movies = _filterAndSort(snap.data!);
          if (movies.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _query.isNotEmpty
                      ? 'No matches for "$_query".'
                      : _hideWatched
                          ? 'No unwatched movies. Toggle the eye icon to show watched.'
                          : 'No movies yet. Tap "Add movie" to get started.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: movies.length,
            itemBuilder: (_, i) => MovieCard(
              movie: movies[i],
              onTap: () => _openForm(existing: movies[i]),
            ),
          );
        },
      ),
    );
  }
}
