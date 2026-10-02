import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';
import '../therapy/therapy_screen.dart';
import 'crisis_resources.dart';

/// Crisis resources: real numbers, one tap from here.
///
/// Everything above the fold is a way to reach a person. The therapy offer
/// sits at the very bottom on purpose — someone in crisis needs a phone
/// number, not an upsell.
class CrisisScreen extends StatefulWidget {
  const CrisisScreen({super.key});

  @override
  State<CrisisScreen> createState() => _CrisisScreenState();
}

class _CrisisScreenState extends State<CrisisScreen> {
  late CrisisRegion _region = defaultCrisisRegion();

  Future<void> _open(Uri uri) async {
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw Exception('not launched');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t open ${uri.scheme == 'tel' ? uri.path : uri}'),
        ),
      );
    }
  }

  Future<void> _pickRegion() async {
    final c = context.brand;
    final picked = await showModalBottomSheet<CrisisRegion>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 18),
            Text(
              'Where are you?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 8),
            for (final region in crisisRegions)
              ListTile(
                title: Text(region.label),
                trailing: region.code == _region.code
                    ? Icon(Icons.check_rounded, color: c.blue)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(region),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (picked != null) setState(() => _region = picked);
  }

  Widget _emergencyCard() {
    final c = context.brand;
    return Material(
      color: c.tint(Pillars.red, 0.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(Uri(scheme: 'tel', path: _region.emergency)),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Pillars.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_rounded,
                    size: 24, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Call ${_region.emergency}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'If you are in immediate danger, this comes first.',
                      style: TextStyle(
                        fontSize: 13,
                        color: c.textMuted,
                        height: 1.4,
                      ),
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

  Widget _lineCard(CrisisLine line) {
    final actions = <({IconData icon, String label, Uri uri})>[
      if (line.phone != null)
        (
          icon: Icons.call_rounded,
          label: 'Call ${line.phone}',
          uri: Uri(scheme: 'tel', path: dialable(line.phone!)),
        ),
      if (line.sms != null)
        (
          icon: Icons.sms_rounded,
          label: 'Text ${line.sms!.$2} to ${line.sms!.$1}',
          uri: Uri(
            scheme: 'sms',
            path: line.sms!.$1,
            queryParameters: {'body': line.sms!.$2},
          ),
        ),
      if (line.url != null)
        (
          icon: Icons.open_in_new_rounded,
          label: 'Open ${Uri.parse(line.url!).host}',
          uri: Uri.parse(line.url!),
        ),
    ];

    final c = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          border: Border.all(color: c.border, width: 1.2),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              line.name,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: c.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              line.detail,
              style: TextStyle(
                fontSize: 13,
                color: c.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            for (final action in actions)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _open(action.uri),
                    icon: Icon(action.icon, size: 18),
                    label: Text(action.label),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.ink,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      side: BorderSide(color: c.border, width: 1.3),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final showInternational = _region.code != internationalRegion.code;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: BackChip(),
                ),
                const SizedBox(height: 20),
                Text(
                  'Help right now',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                const PillarStripe(),
                const SizedBox(height: 16),
                Text(
                  'You do not have to explain yourself well, or be in enough '
                  'trouble to deserve it. Any of these will pick up.',
                  style: TextStyle(
                    fontSize: 14,
                    color: c.textMuted,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 22),
                _emergencyCard(),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _region.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: c.ink,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _pickRegion,
                      child: const Text('Change'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final line in _region.lines) _lineCard(line),
                if (showInternational) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Somewhere else',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final line in internationalRegion.lines) _lineCard(line),
                ],
                const SizedBox(height: 14),
                Text(
                  'This app can\'t replace emergency care. When the moment '
                  'has passed, a licensed therapist here can help you work '
                  'through what led to it.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).push(TherapyScreen.route()),
                  child: const Text('Book a session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The "if you're in crisis" line that closes several screens. It used to
/// be plain text on all of them; now it goes somewhere.
class CrisisFooter extends StatelessWidget {
  const CrisisFooter({
    super.key,
    this.trailing,
    this.textAlign = TextAlign.center,
  });

  /// An optional sentence appended after the crisis line.
  final String? trailing;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CrisisScreen()),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'In crisis or immediate danger? Get help now',
                style: TextStyle(
                  color: c.red,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: c.red,
                ),
              ),
              TextSpan(text: ' — real numbers, one tap.${trailing ?? ''}'),
            ],
          ),
          textAlign: textAlign,
          style: TextStyle(
            fontSize: 12,
            color: c.textMuted,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}
