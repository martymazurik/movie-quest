import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/movie.dart';
import '../services/movie_service.dart';
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
  bool _saving = false;

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
