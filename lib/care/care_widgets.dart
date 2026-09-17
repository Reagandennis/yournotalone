import 'package:flutter/material.dart';

import '../brand.dart';
import '../therapy/therapy_repository.dart';

/// "Couldn't load" with a way to try again.
class LoadFailed extends StatelessWidget {
  const LoadFailed({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Brand.textMuted),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

/// A small rounded label: a payment state, a status, "Inactive".
class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key, this.color = Brand.textMuted});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

StatusBadge paymentBadge(TherapyRequest request, {bool refunded = false}) {
  if (request.isFreeSession) return const StatusBadge('Free', color: Brand.blue);
  return switch (request.paymentStatus) {
    'unpaid' when refunded => const StatusBadge('Refunded', color: Brand.red),
    'unpaid' => const StatusBadge('Unpaid', color: Brand.red),
    'paid' => const StatusBadge('Paid', color: Brand.ink),
    'waived' => const StatusBadge('Waived'),
    _ => const StatusBadge('Free', color: Brand.blue),
  };
}

/// A titled block on the detail screens.
class CareSection extends StatelessWidget {
  const CareSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Brand.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

/// An icon beside a line of text that wraps.
class InfoLine extends StatelessWidget {
  const InfoLine(this.icon, this.text, {super.key, this.trailing, this.color});

  final IconData icon;
  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: color ?? Brand.textMuted),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                color: color ?? Brand.ink,
                height: 1.45,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// A pill that toggles, matching the booking form's topic pills.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0x0A191919) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? Brand.ink : Brand.border,
          width: selected ? 1.6 : 1.2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Brand.ink : Brand.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
