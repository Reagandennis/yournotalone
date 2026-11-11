import 'package:flutter/material.dart';

import '../brand.dart';
import '../l10n/l10n.dart';
import '../support/countries.dart';

/// Asks where someone lives, from every country, with a search box. Returns
/// the chosen ISO code, or null if they close the sheet. [selected] is
/// ticked.
Future<String?> showPriceCountryPicker(
  BuildContext context, {
  String? selected,
}) => showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => _CountrySheet(selected: selected),
);

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({this.selected});

  final String? selected;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  final _countries = countryChoices();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final shown = [
      for (final country in _countries)
        if (countryMatches(country, _query)) country,
    ];
    final media = MediaQuery.of(context);
    return Padding(
      // Keeps the search box above the keyboard.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.therapyPriceCountryTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: c.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  l10n.therapyPriceCountryDetail,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: l10n.therapyPriceCountrySearch,
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shown.length,
                  itemBuilder: (_, index) {
                    final country = shown[index];
                    return ListTile(
                      title: Text(country.name),
                      trailing: country.code == widget.selected
                          ? Icon(Icons.check_rounded, color: c.blue)
                          : null,
                      onTap: () => Navigator.of(context).pop(country.code),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
