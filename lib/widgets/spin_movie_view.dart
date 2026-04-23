import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/movie.dart';
import 'star_rating.dart';

class SpinMovieView extends StatefulWidget {
  final List<Movie> movies;
  const SpinMovieView({super.key, required this.movies});

  @override
  State<SpinMovieView> createState() => SpinMovieViewState();
}

class SpinMovieViewState extends State<SpinMovieView>
    with SingleTickerProviderStateMixin {
  static const double _spacing = 200.0;
  static const double _posterW = 170.0;
  static const double _posterH = 250.0;
  static const double _friction = 0.35;

  late final AnimationController _ctrl;
  double _offsetPx = 0.0;
  int _lastBucket = 0;
  bool _spinning = false;
  bool _dragging = false;
  double? _dragStartOffset;
  final math.Random _rng = math.Random();

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController.unbounded(vsync: this)
      ..addListener(_onTick)
      ..addStatusListener(_onStatus);
    _offsetPx = 0.0;
    _lastBucket = 0;
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTick);
    _ctrl.removeStatusListener(_onStatus);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTick() {
    final v = _ctrl.value;
    final bucket = (v / _spacing).floor();
    if (bucket != _lastBucket) {
      _lastBucket = bucket;
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    }
    setState(() => _offsetPx = v);
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed || s == AnimationStatus.dismissed) {
      if (_spinning) _snapToNearest();
    }
  }

  void _snapToNearest() {
    final target = (_offsetPx / _spacing).round() * _spacing;
    _ctrl.stop();
    _ctrl
        .animateTo(
          target,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        )
        .whenComplete(() {
      if (!mounted) return;
      setState(() {
        _offsetPx = target;
        _spinning = false;
      });
    });
  }

  void triggerRandomSpin() {
    if (widget.movies.length < 2) return;
    final dir = _rng.nextBool() ? 1.0 : -1.0;
    final velocity = dir * (3500.0 + _rng.nextDouble() * 3000.0);
    _launchSim(velocity);
  }

  void _launchSim(double velocity) {
    _ctrl.stop();
    _ctrl.value = _offsetPx;
    _lastBucket = (_offsetPx / _spacing).floor();
    setState(() => _spinning = true);
    final sim = FrictionSimulation(_friction, _offsetPx, velocity);
    _ctrl.animateWith(sim);
  }

  void _onDragStart(DragStartDetails d) {
    _ctrl.stop();
    _dragging = true;
    _dragStartOffset = _offsetPx;
    _lastBucket = (_offsetPx / _spacing).floor();
    setState(() => _spinning = true);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!_dragging) return;
    final newOffset = _offsetPx - d.delta.dx;
    final bucket = (newOffset / _spacing).floor();
    if (bucket != _lastBucket) {
      _lastBucket = bucket;
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.selectionClick();
    }
    setState(() => _offsetPx = newOffset);
  }

  void _onDragEnd(DragEndDetails d) {
    _dragging = false;
    final vx = -d.velocity.pixelsPerSecond.dx;
    final moved = _dragStartOffset == null
        ? 0.0
        : (_offsetPx - _dragStartOffset!).abs();
    if (vx.abs() < 200 && moved < 40) {
      _snapToNearest();
      return;
    }
    _launchSim(vx);
  }

  int _wrap(int i, int len) => ((i % len) + len) % len;

  Movie? get currentMovie {
    if (widget.movies.isEmpty) return null;
    final idx = _wrap((_offsetPx / _spacing).round(), widget.movies.length);
    return widget.movies[idx];
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies;
    if (movies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No movies to spin. Add some — or turn off the eye filter.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (movies.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _PosterTile(
              movie: movies.first,
              scale: 1.0,
              isCenter: true,
              posterW: _posterW,
              posterH: _posterH,
            ),
            const SizedBox(height: 12),
            Expanded(child: _ReadOnlyDetails(movie: movies.first)),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return Column(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: _onDragStart,
              onHorizontalDragUpdate: _onDragUpdate,
              onHorizontalDragEnd: _onDragEnd,
              child: SizedBox(
                width: width,
                height: _posterH + 24,
                child: _buildRoulette(width),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: AnimatedOpacity(
                opacity: _spinning ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: _spinning
                    ? const SizedBox.shrink()
                    : _ReadOnlyDetails(movie: currentMovie!),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRoulette(double width) {
    final movies = widget.movies;
    final continuous = _offsetPx / _spacing;
    final centerIdx = continuous.round();
    final indices = <int>[
      centerIdx - 2,
      centerIdx - 1,
      centerIdx,
      centerIdx + 1,
      centerIdx + 2,
    ];
    indices.sort((a, b) =>
        (b - continuous).abs().compareTo((a - continuous).abs()));

    final cx = width / 2;
    final cy = (_posterH + 24) / 2;

    return Stack(
      clipBehavior: Clip.none,
      children: indices.map((i) {
        final dist = (i - continuous).abs();
        final dx = (i - continuous) * _spacing;
        final scale = (1.0 - dist * 0.18).clamp(0.55, 1.0).toDouble();
        final opacity = (1.0 - dist * 0.35).clamp(0.15, 1.0).toDouble();
        final wrappedIdx = _wrap(i, movies.length);
        final movie = movies[wrappedIdx];
        final isCenter = dist < 0.5;
        return Positioned(
          left: cx + dx - (_posterW * scale) / 2,
          top: cy - (_posterH * scale) / 2,
          child: Opacity(
            opacity: opacity,
            child: _PosterTile(
              movie: movie,
              scale: scale,
              isCenter: isCenter,
              posterW: _posterW,
              posterH: _posterH,
              showPlay: isCenter && !_spinning,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _PosterTile extends StatelessWidget {
  final Movie movie;
  final double scale;
  final bool isCenter;
  final double posterW;
  final double posterH;
  final bool showPlay;

  const _PosterTile({
    required this.movie,
    required this.scale,
    required this.isCenter,
    required this.posterW,
    required this.posterH,
    this.showPlay = false,
  });

  Future<void> _openTrailer(BuildContext context) async {
    final raw = movie.trailerUrl?.trim();
    if (raw == null || raw.isEmpty) return;
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open trailer: $raw')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = posterW * scale;
    final h = posterH * scale;
    final theme = Theme.of(context);
    final url = movie.thumbnailUrl;

    final fallback = Container(
      width: w,
      height: h,
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          movie.title,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium,
        ),
      ),
    );

    Widget image;
    if (url == null || url.isEmpty) {
      image = fallback;
    } else {
      image = Image.network(
        url,
        width: w,
        height: h,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return SizedBox(
            width: w,
            height: h,
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: w, height: h, child: image),
    );

    final decorated = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: isCenter
            ? const [
                BoxShadow(
                  color: Color(0xFFFFD54F),
                  blurRadius: 28,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Color(0x66FFC107),
                  blurRadius: 48,
                  spreadRadius: 6,
                ),
              ]
            : const [],
      ),
      child: clipped,
    );

    if (!showPlay) return decorated;

    final hasTrailer =
        movie.trailerUrl != null && movie.trailerUrl!.trim().isNotEmpty;
    if (!hasTrailer) return decorated;

    return Stack(
      alignment: Alignment.center,
      children: [
        decorated,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _openTrailer(context),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        IgnorePointer(
          child: Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: Color(0xFFFF0000),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black54, blurRadius: 10),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReadOnlyDetails extends StatelessWidget {
  final Movie movie;
  const _ReadOnlyDetails({required this.movie});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watchStr = movie.watchDate == null
        ? null
        : DateFormat.yMMMd().format(movie.watchDate!);
    final actorsStr = movie.actors.isEmpty ? null : movie.actors.join(', ');
    final awardsStr = movie.awards.isEmpty ? null : movie.awards.join(' • ');
    final htw = (movie.howToWatch ?? '').trim();
    final titleText = movie.releaseYear == null
        ? movie.title
        : '${movie.title} (${movie.releaseYear})';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titleText,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              StarRating(value: movie.ourRating, size: 16),
              const SizedBox(width: 4),
              Text('(our)', style: theme.textTheme.bodySmall),
              const SizedBox(width: 10),
              Text(
                movie.externalRating.toStringAsFixed(1),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(Icons.star, size: 14, color: Colors.amber),
              Text(' (ext)', style: theme.textTheme.bodySmall),
            ],
          ),
          if (movie.description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              movie.description,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (actorsStr != null) ...[
            const SizedBox(height: 4),
            Text(
              actorsStr,
              style: theme.textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (awardsStr != null) ...[
            const SizedBox(height: 4),
            Text(
              awardsStr,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (watchStr != null || htw.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (watchStr != null) 'Watched $watchStr',
                if (htw.isNotEmpty) 'on $htw',
              ].join(' '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (movie.enteredBy.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Entered by ${movie.enteredBy}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
