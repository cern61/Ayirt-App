import 'package:flutter/material.dart';

import '../data/models/booking.dart';

/// İşletme logosu; logo yoksa adının baş harfi
class BusinessAvatar extends StatelessWidget {
  const BusinessAvatar({super.key, required this.name, this.logoUrl, this.size = 52});
  final String name;
  final String? logoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: SizedBox(
        width: size,
        height: size,
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(logoUrl!, fit: BoxFit.cover, errorBuilder: (context, error, stack) => _fallback(scheme, initial))
            : _fallback(scheme, initial),
      ),
    );
  }

  Widget _fallback(ColorScheme scheme, String initial) => Container(
        color: scheme.primaryContainer,
        alignment: Alignment.center,
        child: Text(initial,
            style: TextStyle(fontSize: size * 0.42, fontWeight: FontWeight.bold, color: scheme.onPrimaryContainer)),
      );
}

/// ★ 4.5 (12)
class RatingBadge extends StatelessWidget {
  const RatingBadge({super.key, required this.avg, required this.count});
  final double avg;
  final int count;

  @override
  Widget build(BuildContext context) {
    if (count == 0) {
      return const Text('Yeni', style: TextStyle(color: Colors.grey, fontSize: 13));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
      const SizedBox(width: 2),
      Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
      Text(' ($count)', style: const TextStyle(color: Colors.grey, fontSize: 13)),
    ]);
  }
}

/// Dokunarak puan verilebilen yıldızlar
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 1; i <= 5; i++)
        IconButton(
          iconSize: 36,
          onPressed: () => onChanged(i),
          icon: Icon(i <= value ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber),
        ),
    ]);
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final BookingStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      BookingStatus.pending => (Colors.orange.shade50, Colors.orange.shade800),
      BookingStatus.confirmed => (Colors.green.shade50, Colors.green.shade800),
      BookingStatus.cancelled => (Colors.red.shade50, Colors.red.shade700),
      BookingStatus.completed => (Colors.blue.shade50, Colors.blue.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status.label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

/// Boş liste / hata durumları için ortak görünüm
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
        if (action != null) ...[const SizedBox(height: 12), action!],
      ]),
    );
  }
}
