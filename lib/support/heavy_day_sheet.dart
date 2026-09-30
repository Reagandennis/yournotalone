import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../brand.dart';
import '../home/mood_face.dart';
import '../home/mood_scale.dart';
import '../therapy/therapy_screen.dart';
import 'crisis_resources.dart';
import 'crisis_screen.dart';

/// Shown after an "Awful" check-in.
///
/// A heavy day is a reason to talk to someone, and usually not an
/// emergency, so this leads with the therapist. The emergency numbers
/// stay one tap away at the bottom for the times it is more than that,
/// and the full crisis page is a link from there.
Future<void> showHeavyDaySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _HeavyDaySheet(
      onBook: () {
        Navigator.of(sheetContext).pop();
        Navigator.of(context).push(TherapyScreen.route());
      },
      onMoreHelp: () {
        Navigator.of(sheetContext).pop();
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CrisisScreen()),
        );
      },
    ),
  );
}

class _HeavyDaySheet extends StatelessWidget {
  const _HeavyDaySheet({required this.onBook, required this.onMoreHelp});

  final VoidCallback onBook;
  final VoidCallback onMoreHelp;

  Future<void> _call(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: dialable(number));
    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('not launched');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t call $number')),
      );
    }
  }

  Widget _callButton(
    BuildContext context, {
    required String name,
    required String number,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => _call(context, number),
          icon: const Icon(Icons.call_rounded, size: 18, color: Brand.red),
          label: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '  ·  $number',
                  style: const TextStyle(color: Brand.textMuted),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: Brand.ink,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            side: const BorderSide(color: Brand.border, width: 1.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final region = defaultCrisisRegion();
    final lines = [
      for (final line in region.lines)
        if (line.phone != null) line,
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: MoodFace(level: moodLevels.first, size: 56)),
            const SizedBox(height: 16),
            const Text(
              'That sounds like a heavy day.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You don\'t have to carry it on your own. A licensed therapist '
              'here will listen — \$20 a session, booked in a minute.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Brand.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onBook,
              child: const Text('Book a session'),
            ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Not now'),
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Brand.border),
            const SizedBox(height: 16),
            const Text(
              'If you need someone right now',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Brand.ink,
              ),
            ),
            const SizedBox(height: 10),
            _callButton(
              context,
              name: 'Emergency',
              number: region.emergency,
            ),
            for (final line in lines)
              _callButton(context, name: line.name, number: line.phone!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onMoreHelp,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: Brand.red,
                ),
                child: const Text('More ways to get help'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
