import 'package:flutter/material.dart';

class StarRating extends StatelessWidget {
  final int value;
  final int max;
  final double size;
  final Color? color;
  final ValueChanged<int>? onChanged;

  const StarRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 24,
    this.color,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.amber;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < value;
        final star = Icon(
          filled ? Icons.star : Icons.star_border,
          size: size,
          color: c,
        );
        if (onChanged == null) return star;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            final next = (value == i + 1) ? 0 : i + 1;
            onChanged!(next);
          },
          child: Padding(padding: const EdgeInsets.all(2), child: star),
        );
      }),
    );
  }
}

class HalfStarRating extends StatelessWidget {
  final double value;
  final int max;
  final double size;
  final Color color;

  const HalfStarRating({
    super.key,
    required this.value,
    this.max = 5,
    this.size = 18,
    this.color = Colors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final diff = value - i;
        IconData icon;
        if (diff >= 1) {
          icon = Icons.star;
        } else if (diff >= 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
