import 'package:flutter/material.dart';

import '../brand.dart';
import 'legal_content.dart';

/// Renders a [LegalDoc] (Privacy Policy / Terms of Service) as a
/// scrollable, numbered document in the app's house style.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    return Scaffold(
      appBar: AppBar(title: Text(doc.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
              children: [
                const PillarStripe(),
                const SizedBox(height: 14),
                Text(
                  'Last updated: $legalLastUpdated',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  doc.intro,
                  style: TextStyle(
                    fontSize: 14,
                    color: c.ink,
                    height: 1.6,
                  ),
                ),
                for (final (i, section) in doc.sections.indexed) ...[
                  const SizedBox(height: 26),
                  Text(
                    '${i + 1}. ${section.heading}',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                      color: c.ink,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    section.body,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: c.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
