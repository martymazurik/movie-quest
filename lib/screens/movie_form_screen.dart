import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
import '../services/omdb_service.dart';
import '../services/tmdb_service.dart';
import '../services/user_service.dart';
import '../widgets/star_rating.dart';

class MovieFormScreen extends StatefulWidget {
  final Movie? existing;
  const MovieFormScreen({super.key, this.existing});

  @override
  State<MovieFormScreen> createState() => _MovieFormScreenState();
}

class _MovieFormScreenState extends State<MovieFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _actors;
  late final TextEditingController _awards;
  late final TextEditingController _releaseYear;
  late final TextEditingController _externalRating;
  late final TextEditingController _trailerUrl;
  late final TextEditingController _thumbnailUrl;
  late final TextEditingController _howToWatchOther;
  DateTime? _watchDate;
  int _ourRating = 0;
  String? _howToWatchChoice;
  String? _genre;
  bool _saving = false;

  bool _looking = false;
  int _searchSeq = 0;

  static const _presetServices = ['Netflix', 'Prime', 'HBOMax'];

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _title = TextEditingController(text: m?.title ?? '');
    _description = TextEditingController(text: m?.description ?? '');
    _actors = TextEditingController(text: m?.actors.join(', ') ?? '');
    _awards = TextEditingController(text: m?.awards.join(', ') ?? '');
    _releaseYear =
        TextEditingController(text: m?.releaseYear?.toString() ?? '');
    _externalRating = TextEditingController(
      text: m?.externalRating.toStringAsFixed(1) ?? '',
    );
    _trailerUrl = TextEditingController(text: m?.trailerUrl ?? '');
    _thumbnailUrl = TextEditingController(text: m?.thumbnailUrl ?? '');
    _watchDate = m?.watchDate;
    _ourRating = m?.ourRating ?? 0;
    _genre = (m?.genre != null && kImdbGenres.contains(m!.genre)) ? m.genre : null;

    final existingHtw = m?.howToWatch;
    if (existingHtw == null || existingHtw.isEmpty) {
      _howToWatchChoice = null;
      _howToWatchOther = TextEditingController();
    } else if (_presetServices.contains(existingHtw)) {
      _howToWatchChoice = existingHtw;
      _howToWatchOther = TextEditingController();
    } else {
      _howToWatchChoice = 'Other';
      _howToWatchOther = TextEditingController(text: existingHtw);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _actors.dispose();
    _awards.dispose();
    _releaseYear.dispose();
    _externalRating.dispose();
    _trailerUrl.dispose();
    _thumbnailUrl.dispose();
    _howToWatchOther.dispose();
    super.dispose();
  }

  void _applyLookupResult(TmdbLookupResult result) {
    setState(() {
      if (_title.text.trim().isEmpty) _title.text = result.title;
      if (_description.text.trim().isEmpty && result.description != null) {
        _description.text = result.description!;
      }
      if (_releaseYear.text.trim().isEmpty && result.releaseYear != null) {
        _releaseYear.text = result.releaseYear!.toString();
      }
      if (_externalRating.text.trim().isEmpty &&
          result.externalRating != null) {
        _externalRating.text = result.externalRating!.toStringAsFixed(1);
      }
      if (_actors.text.trim().isEmpty && result.actors.isNotEmpty) {
        _actors.text = result.actors.join(', ');
      }
      if (_thumbnailUrl.text.trim().isEmpty && result.thumbnailUrl != null) {
        _thumbnailUrl.text = result.thumbnailUrl!;
      }
      if (_trailerUrl.text.trim().isEmpty && result.trailerUrl != null) {
        _trailerUrl.text = result.trailerUrl!;
      }
      if (_genre == null && result.genre != null) {
        _genre = result.genre;
      }
      if (_howToWatchChoice == null && result.howToWatch != null) {
        final name = result.howToWatch!;
        if (_presetServices.contains(name)) {
          _howToWatchChoice = name;
        } else {
          _howToWatchChoice = 'Other';
          if (_howToWatchOther.text.trim().isEmpty) {
            _howToWatchOther.text = name;
          }
        }
      }
    });
  }

  Future<void> _onHitSelected(TmdbSearchHit hit) async {
    if (_looking) return;
    setState(() => _looking = true);
    try {
      final result = await TmdbService.fetchDetails(id: hit.id, isTv: hit.isTv);
      if (!mounted) return;
      _applyLookupResult(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isTvSeries
                ? 'Filled from TMDB (TV series).'
                : 'Filled from TMDB.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
      if (result.imdbId != null && OmdbService.isConfigured) {
        try {
          final awards = await OmdbService.fetchTopAwards(result.imdbId!);
          if (!mounted) return;
          if (awards.isNotEmpty && _awards.text.trim().isEmpty) {
            setState(() => _awards.text = awards.join(', '));
          }
        } catch (_) {
          // Awards are best-effort; silently skip.
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-fill failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _looking = false);
    }
  }

  Future<Iterable<TmdbSearchHit>> _searchOptions(String query) async {
    final q = query.trim();
    if (q.length < 2) return const Iterable.empty();
    if (!TmdbService.isConfigured) return const Iterable.empty();
    _searchSeq++;
    final mySeq = _searchSeq;
    await Future.delayed(const Duration(milliseconds: 250));
    if (mySeq != _searchSeq) return const Iterable.empty();
    try {
      return await TmdbService.searchMulti(q);
    } catch (_) {
      return const Iterable.empty();
    }
  }

  List<String> _splitCsv(String s) => s
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Future<void> _pickWatchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _watchDate ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _watchDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final enteredBy = (await UserService.getName()) ?? 'Unknown';
      final year = int.tryParse(_releaseYear.text.trim());
      final ext = double.tryParse(_externalRating.text.trim()) ?? 0.0;
      String? howToWatch;
      if (_howToWatchChoice == 'Other') {
        final other = _howToWatchOther.text.trim();
        howToWatch = other.isEmpty ? null : other;
      } else {
        howToWatch = _howToWatchChoice;
      }
      final movie = Movie(
        id: widget.existing?.id,
        title: _title.text.trim(),
        description: _description.text.trim(),
        actors: _splitCsv(_actors.text),
        releaseYear: year,
        externalRating: ext.clamp(0.0, 5.0).toDouble(),
        ourRating: _ourRating,
        awards: _splitCsv(_awards.text),
        watchDate: _watchDate,
        trailerUrl: _trailerUrl.text.trim().isEmpty
            ? null
            : _trailerUrl.text.trim(),
        thumbnailUrl: _thumbnailUrl.text.trim().isEmpty
            ? null
            : _thumbnailUrl.text.trim(),
        howToWatch: howToWatch,
        genre: _genre,
        enteredBy: widget.existing?.enteredBy.isNotEmpty == true
            ? widget.existing!.enteredBy
            : enteredBy,
      );
      if (_isEdit) {
        await MovieService.update(movie);
      } else {
        await MovieService.add(movie);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
      setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete() async {
    final id = widget.existing?.id;
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete movie?'),
        content: Text('"${widget.existing!.title}" will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await MovieService.delete(id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchStr = _watchDate == null
        ? 'Pick a date'
        : DateFormat.yMMMd().format(_watchDate!);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit movie' : 'Add movie'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!_isEdit) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 18),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Search TMDB and auto-fill',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (_looking)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<TmdbSearchHit>(
                      displayStringForOption: (h) =>
                          '${h.title}${h.yearLabel}',
                      optionsBuilder: (tev) => _searchOptions(tev.text),
                      onSelected: _onHitSelected,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmitted) {
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: const InputDecoration(
                            hintText: 'Start typing a title…',
                            prefixIcon: Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => onSubmitted(),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 4,
                            borderRadius: BorderRadius.circular(8),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 320,
                                maxWidth: 480,
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: EdgeInsets.zero,
                                itemCount: options.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final h = options.elementAt(i);
                                  return InkWell(
                                    onTap: () => onSelected(h),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 36,
                                            height: 54,
                                            child: h.posterUrl == null
                                                ? Container(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest,
                                                    child: const Icon(
                                                      Icons.movie,
                                                      size: 18,
                                                    ),
                                                  )
                                                : Image.network(
                                                    h.posterUrl!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder:
                                                        (_, __, ___) =>
                                                            const Icon(
                                                      Icons.movie,
                                                      size: 18,
                                                    ),
                                                  ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '${h.title}${h.yearLabel}',
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  h.typeLabel,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Watch date',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(watchStr)),
                  if (_watchDate != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => _watchDate = null),
                    ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: const Text('Pick'),
                    onPressed: _pickWatchDate,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Our rating', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            StarRating(
              value: _ourRating,
              size: 36,
              onChanged: (v) => setState(() => _ourRating = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLength: 255,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 4),
            TextFormField(
              controller: _actors,
              decoration: const InputDecoration(
                labelText: 'Actors (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _releaseYear,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Release year',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final y = int.tryParse(v.trim());
                      if (y == null || y < 1870 || y > DateTime.now().year + 5) {
                        return 'Invalid year';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _externalRating,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'External rating (0–5)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final d = double.tryParse(v.trim());
                      if (d == null || d < 0 || d > 5) return '0.0 – 5.0';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              value: _genre,
              decoration: const InputDecoration(
                labelText: 'Genre',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('— None —'),
                ),
                ...kImdbGenres.map(
                  (g) => DropdownMenuItem<String?>(value: g, child: Text(g)),
                ),
              ],
              onChanged: (v) => setState(() => _genre = v),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _awards,
              decoration: const InputDecoration(
                labelText: 'Awards (comma-separated)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thumbnailUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Thumbnail URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _trailerUrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Trailer URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _howToWatchChoice,
              decoration: const InputDecoration(
                labelText: 'How to watch',
                border: OutlineInputBorder(),
              ),
              items: [
                ..._presetServices.map(
                  (s) => DropdownMenuItem(value: s, child: Text(s)),
                ),
                const DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _howToWatchChoice = v),
            ),
            if (_howToWatchChoice == 'Other') ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _howToWatchOther,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Other service',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (_howToWatchChoice != 'Other') return null;
                  if (v == null || v.trim().isEmpty) {
                    return 'Enter the service name';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save),
              label: Text(_isEdit ? 'Save changes' : 'Add movie'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
