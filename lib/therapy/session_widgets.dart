import 'package:flutter/material.dart';

import '../brand.dart';
import 'therapy_repository.dart';

/// A therapist's photo, or their initial when there isn't one.
class TherapistAvatar extends StatelessWidget {
  const TherapistAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 48,
  });

  final String name;
  final String? photoUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final trimmed = name.trim();
    final initial = Center(
      child: Text(
        trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: c.blue,
        ),
      ),
    );
    final url = photoUrl ?? '';
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.tint(Pillars.blue, 0.08),
        shape: BoxShape.circle,
      ),
      child: url.isEmpty
          ? initial
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => initial,
            ),
    );
  }
}

/// Five stars showing a rating, halves included.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Semantics(
      label: '${rating.toStringAsFixed(1)} out of 5 stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 1; i <= 5; i++)
              Icon(
                rating >= i
                    ? Icons.star_rounded
                    : rating >= i - 0.5
                        ? Icons.star_half_rounded
                        : Icons.star_outline_rounded,
                size: size,
                color: c.yellow,
              ),
          ],
        ),
      ),
    );
  }
}

/// Tap a star to rate from 1 to 5; 0 means nothing chosen yet.
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.size = 38,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= 5; i++)
          IconButton(
            tooltip: '$i out of 5',
            onPressed: () => onChanged(i),
            icon: Icon(
              i <= value ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= value ? c.yellow : c.tint(Pillars.black, 0.12),
            ),
          ),
      ],
    );
  }
}

/// The therapist someone has been matched with; tap for the full profile.
class TherapistCard extends StatelessWidget {
  const TherapistCard({super.key, required this.profile});

  final TherapistProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final rating = profile.ratingAverage;
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: c.border, width: 1.2),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTherapistProfile(context, profile),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TherapistAvatar(
                name: profile.fullName,
                photoUrl: profile.photoUrl,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: c.ink,
                      ),
                    ),
                    if (profile.title != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        profile.title!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: c.textMuted,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (rating != null) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          StarRow(rating: rating),
                          const SizedBox(width: 6),
                          Text(
                            '${rating.toStringAsFixed(1)} · ${profile.ratingCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: c.border,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showTherapistProfile(
  BuildContext context,
  TherapistProfile profile,
) {
  final c = context.brand;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
        children: [
          Center(
            child: TherapistAvatar(
              name: profile.fullName,
              photoUrl: profile.photoUrl,
              size: 84,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: c.ink,
            ),
          ),
          if (profile.title != null) ...[
            const SizedBox(height: 4),
            Text(
              profile.title!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: c.textMuted),
            ),
          ],
          if (profile.ratingAverage != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StarRow(rating: profile.ratingAverage!, size: 17),
                const SizedBox(width: 6),
                Text(
                  '${profile.ratingAverage!.toStringAsFixed(1)} from '
                  '${profile.ratingCount} ratings',
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          if (profile.credentials != null)
            _ProfileLine(Icons.verified_rounded, profile.credentials!),
          if (profile.yearsExperience != null)
            _ProfileLine(
              Icons.workspace_premium_outlined,
              profile.yearsExperience == 1
                  ? '1 year of experience'
                  : '${profile.yearsExperience} years of experience',
            ),
          if (profile.languages.isNotEmpty)
            _ProfileLine(Icons.translate_rounded, profile.languages.join(', ')),
          if (profile.specialties.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final specialty in profile.specialties)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: c.tint(Pillars.blue, 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      specialty,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: c.blue,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (profile.bio != null) ...[
            const SizedBox(height: 18),
            Text(
              profile.bio!,
              style: TextStyle(
                fontSize: 14,
                color: c.ink,
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13.5, color: c.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stars and an optional comment in a bottom sheet. Returns true once
/// [onSubmit] has succeeded; errors stay in the sheet so nothing typed is
/// lost.
Future<bool?> showSessionRatingSheet(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String commentLabel,
  required Future<void> Function(int rating, String? comment) onSubmit,
  required String Function(Object error) describeError,
  int initialRating = 0,
  String? initialComment,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RatingSheet(
      title: title,
      subtitle: subtitle,
      commentLabel: commentLabel,
      onSubmit: onSubmit,
      describeError: describeError,
      initialRating: initialRating,
      initialComment: initialComment,
    ),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({
    required this.title,
    required this.subtitle,
    required this.commentLabel,
    required this.onSubmit,
    required this.describeError,
    required this.initialRating,
    required this.initialComment,
  });

  final String title;
  final String subtitle;
  final String commentLabel;
  final Future<void> Function(int rating, String? comment) onSubmit;
  final String Function(Object error) describeError;
  final int initialRating;
  final String? initialComment;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  late int _rating = widget.initialRating;
  late final _comment = TextEditingController(text: widget.initialComment);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final comment = _comment.text.trim();
      await widget.onSubmit(_rating, comment.isEmpty ? null : comment);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = widget.describeError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: c.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            StarRatingInput(
              value: _rating,
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              decoration: InputDecoration(
                labelText: widget.commentLabel,
                alignLabelWithHint: true,
                counterText: '',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(fontSize: 13, color: c.red),
              ),
            ],
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: _rating == 0 || _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send rating'),
            ),
          ],
        ),
      ),
    );
  }
}
