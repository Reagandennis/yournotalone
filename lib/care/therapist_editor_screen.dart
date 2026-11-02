import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
import '../l10n/l10n.dart';
import '../therapy/session_format.dart';
import '../therapy/session_widgets.dart';
import '../therapy/therapy_repository.dart';
import 'care_repository.dart';
import 'care_widgets.dart';

/// What a therapist can be matched on. The request topics come first, so a
/// request's topic lines up with a specialty exactly.
final _specialtyOptions = [
  for (final topic in therapyTopics)
    if (topic != 'Not sure yet') topic,
  'Trauma',
  'Family & parenting',
];

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Add a therapist, or edit one: their profile as clients see it, the email
/// they sign in with, and — for the care team only — how clients rated them.
/// Pops with true once saved.
class TherapistEditorScreen extends StatefulWidget {
  const TherapistEditorScreen({
    super.key,
    this.therapist,
    required this.repository,
    this.feedback = const [],
  });

  final AdminTherapist? therapist;
  final CareRepository repository;

  /// This therapist's sessions that a client has rated.
  final List<AdminTherapyRequest> feedback;

  @override
  State<TherapistEditorScreen> createState() => _TherapistEditorScreenState();
}

class _TherapistEditorScreenState extends State<TherapistEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _existing = widget.therapist?.profile;
  late final _name = TextEditingController(text: _existing?.fullName);
  late final _email = TextEditingController(text: widget.therapist?.email);
  late final _title = TextEditingController(text: _existing?.title);
  late final _credentials =
      TextEditingController(text: _existing?.credentials);
  late final _years =
      TextEditingController(text: _existing?.yearsExperience?.toString());
  late final _languages =
      TextEditingController(text: _existing?.languages.join(', '));
  late final _bio = TextEditingController(text: _existing?.bio);
  late final _specialties = <String>{...?_existing?.specialties};
  late bool _active = _existing?.active ?? true;
  Uint8List? _photo;
  bool _removePhoto = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _title,
      _credentials,
      _years,
      _languages,
      _bio,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _removePhoto = false;
      });
    } catch (_) {
      if (mounted) _say(context.l10n.careEditorPhotoFailed);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      var photoUrl = _removePhoto ? null : _existing?.photoUrl;
      final photo = _photo;
      if (photo != null) {
        photoUrl = await widget.repository
            .uploadTherapistPhoto(photo, therapistId: _existing?.id);
      }
      await widget.repository.saveTherapist(
        id: _existing?.id,
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        title: _title.text.trim(),
        credentials: _credentials.text.trim(),
        bio: _bio.text.trim(),
        specialties: [
          ..._specialtyOptions.where(_specialties.contains),
          ..._specialties.where((s) => !_specialtyOptions.contains(s)),
        ],
        languages: [
          for (final part in _languages.text.split(','))
            if (part.trim().isNotEmpty) part.trim(),
        ],
        yearsExperience: int.tryParse(_years.text.trim()),
        photoUrl: photoUrl,
        active: _active,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _say(careErrorMessage(e, context.l10n.careCouldNotSave));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final l10n = context.l10n;
    final existing = widget.therapist;
    final photoUrl = _removePhoto ? null : _existing?.photoUrl;
    final photo = _photo;
    final hasPhoto = photo != null || (photoUrl?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null
            ? l10n.careEditorTitleAdd
            : l10n.careEditorTitleEdit),
      ),
      body: ReadableWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              Center(
                child: photo != null
                    ? ClipOval(
                        child: Image.memory(
                          photo,
                          width: 96,
                          height: 96,
                          fit: BoxFit.cover,
                        ),
                      )
                    : TherapistAvatar(
                        name: _name.text,
                        photoUrl: photoUrl,
                        size: 96,
                      ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _saving ? null : _pickPhoto,
                    child: Text(hasPhoto
                        ? l10n.careEditorChangePhoto
                        : l10n.careEditorAddPhoto),
                  ),
                  if (hasPhoto)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _photo = null;
                                _removePhoto = true;
                              }),
                      style: TextButton.styleFrom(foregroundColor: c.red),
                      child: Text(l10n.commonRemove),
                    ),
                ],
              ),
              if (existing != null) ...[
                const SizedBox(height: 8),
                _stats(existing),
              ],
              const SizedBox(height: 20),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration:
                    InputDecoration(labelText: l10n.careEditorFullName),
                validator: (value) => (value ?? '').trim().length < 2
                    ? l10n.careEditorFullNameError
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: l10n.careEditorEmail,
                  helperText: l10n.careEditorEmailHelp,
                  helperMaxLines: 2,
                ),
                validator: (value) => _emailPattern.hasMatch((value ?? '').trim())
                    ? null
                    : l10n.careEditorEmailError,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.careEditorTitleField,
                  hintText: l10n.careEditorTitleHint,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _credentials,
                decoration: InputDecoration(
                  labelText: l10n.careEditorLicence,
                  hintText: l10n.careEditorLicenceHint,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: l10n.careEditorYears),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final years = int.tryParse(text);
                  return years == null || years < 0 || years > 70
                      ? l10n.careEditorYearsError
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _languages,
                decoration: InputDecoration(
                  labelText: l10n.careEditorLanguages,
                  hintText: l10n.careEditorLanguagesHint,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bio,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.careEditorAbout,
                  helperText: l10n.careEditorAboutHelp,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: l10n.careEditorSpecialties),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final specialty in {..._specialtyOptions, ..._specialties})
                    ChoicePill(
                      label: specialty,
                      selected: _specialties.contains(specialty),
                      onTap: () => setState(() {
                        if (!_specialties.remove(specialty)) {
                          _specialties.add(specialty);
                        }
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _active,
                onChanged: (value) => setState(() => _active = value),
                title: Text(
                  l10n.careEditorTakingClients,
                  style: TextStyle(fontSize: 14.5, color: c.ink),
                ),
                subtitle: Text(
                  l10n.careEditorTakingClientsHint,
                  style: TextStyle(fontSize: 12.5, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white,
                        ),
                      )
                    : Text(existing == null
                        ? l10n.careEditorAddButton
                        : l10n.commonSave),
              ),
              if (existing == null) ...[
                const SizedBox(height: 10),
                Text(
                  l10n.careEditorInviteNote,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
              if (widget.feedback.isNotEmpty) ...[
                const SizedBox(height: 30),
                SectionHeader(title: l10n.careEditorFeedback),
                const SizedBox(height: 4),
                Text(
                  l10n.careEditorFeedbackNote,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                for (final item in widget.feedback) _feedbackRow(item),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _stats(AdminTherapist therapist) {
    final c = context.brand;
    final l10n = context.l10n;
    final rating = therapist.profile.ratingAverage;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.tint(Pillars.black, 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.careEditorStats(
                therapist.upcomingSessions, therapist.completedSessions),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: c.ink,
            ),
          ),
          if (rating != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                StarRow(rating: rating),
                const SizedBox(width: 6),
                Text(
                  l10n.careEditorRatingFrom(
                      rating.toStringAsFixed(1), therapist.profile.ratingCount),
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            therapist.hasAccount
                ? l10n.careEditorSignedInAs(therapist.email)
                : l10n.careEditorNotSignedIn(therapist.email),
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: therapist.hasAccount ? c.textMuted : c.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedbackRow(AdminTherapyRequest item) {
    final c = context.brand;
    final when = item.request.scheduledAt ?? item.request.createdAt;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StarRow(rating: (item.clientRating ?? 0).toDouble()),
              const Spacer(),
              Text(
                formatDate(when),
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
          if (item.clientComment != null) ...[
            const SizedBox(height: 6),
            Text(
              item.clientComment!,
              style: TextStyle(fontSize: 13, color: c.ink, height: 1.45),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            item.clientLabel(context.l10n),
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
