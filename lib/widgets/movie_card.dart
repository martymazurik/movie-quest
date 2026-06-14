import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/movie.dart';
import 'star_rating.dart';

class MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback? onTap;

  const MovieCard({super.key, required this.movie, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final watchStr = movie.watchDate == null
        ? null
        : DateFormat.yMMMd().format(movie.watchDate!);
    final actorsStr = movie.actors.isEmpty ? null : movie.actors.join(', ');
    final awardsStr = movie.awards.isEmpty ? null : movie.awards.join(' • ');
    final htw = (movie.howToWatch ?? '').trim();
    String? watchedBit;
    if (watchStr != null && htw.isNotEmpty) {
      watchedBit = 'Watched $watchStr on $htw';
    } else if (watchStr != null) {
      watchedBit = 'Watched $watchStr';
    } else if (htw.isNotEmpty) {
      watchedBit = 'On $htw';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(
                url: movie.thumbnailUrl,
                trailerUrl: movie.trailerUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            movie.releaseYear == null
                                ? movie.title
                                : '${movie.title} (${movie.releaseYear})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          movie.externalRating.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 2),
                        Text('(ext)', style: theme.textTheme.bodySmall),
                        if ((movie.genre ?? '').isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              movie.genre!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 10,
                                color: theme.colorScheme.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (movie.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        movie.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    if (actorsStr != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        actorsStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    if (awardsStr != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        awardsStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        StarRating(value: movie.ourRating, size: 16),
                        const SizedBox(width: 6),
                        Text('(our)', style: theme.textTheme.bodySmall),
                        if (watchedBit != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              watchedBit,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final String? url;
  final String? trailerUrl;
  const _Thumbnail({required this.url, this.trailerUrl});

  Future<void> _openTrailer(BuildContext context) async {
    final raw = trailerUrl?.trim();
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
    const w = 64.0;
    const h = 96.0;
    final hasTrailer = trailerUrl != null && trailerUrl!.trim().isNotEmpty;
    final fallback = Container(
      width: w,
      height: h,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.movie, size: 32),
    );

    Widget image;
    if (url == null || url!.isEmpty) {
      image = fallback;
    } else {
      image = Image.network(
        url!,
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
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    Widget content = image;
    if (hasTrailer) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          image,
          Container(
            width: w,
            height: h,
            color: Colors.black.withOpacity(0.25),
          ),
          const Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
        ],
      );
    }

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(width: w, height: h, child: content),
    );

    if (!hasTrailer) return clipped;

    return Tooltip(
      message: 'Play trailer',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _openTrailer(context),
          child: clipped,
        ),
      ),
    );
  }
}
