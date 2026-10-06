import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../brand.dart';
import '../brand_layout.dart';
import '../home/home_ui.dart';
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
      if (mounted) _say('Couldn\'t open your photo library.');
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
      _say(careErrorMessage(e, 'Couldn\'t save — check your connection.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.brand;
    final existing = widget.therapist;
    final photoUrl = _removePhoto ? null : _existing?.photoUrl;
    final photo = _photo;
    final hasPhoto = photo != null || (photoUrl?.isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(
        title: Text(existing == null ? 'Add a therapist' : 'Edit therapist'),
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
                    child: Text(hasPhoto ? 'Change photo' : 'Add a photo'),
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
                      child: const Text('Remove'),
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
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) => (value ?? '').trim().length < 2
                    ? 'Enter their full name'
                    : null,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Sign-in email',
                  helperText: 'They sign in to the app with this address.',
                  helperMaxLines: 2,
                ),
                validator: (value) => _emailPattern.hasMatch((value ?? '').trim())
                    ? null
                    : 'Enter a valid email',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'Counselling psychologist',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _credentials,
                decoration: const InputDecoration(
                  labelText: 'Licence or registration',
                  hintText: 'Body and registration number',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _years,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Years of experience'),
                validator: (value) {
                  final text = (value ?? '').trim();
                  if (text.isEmpty) return null;
                  final years = int.tryParse(text);
                  return years == null || years < 0 || years > 70
                      ? 'A number from 0 to 70'
                      : null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _languages,
                decoration: const InputDecoration(
                  labelText: 'Languages',
                  hintText: 'English, Swahili',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _bio,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'About them',
                  helperText: 'Clients read this on their profile.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              const SectionHeader(title: 'Specialties'),
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
                  'Taking new clients',
                  style: TextStyle(fontSize: 14.5, color: c.ink),
                ),
                subtitle: Text(
                  'When off, they can\'t be matched. Their booked and past '
                  'sessions stay.',
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
                    : Text(existing == null ? 'Add therapist' : 'Save'),
              ),
              if (existing == null) ...[
                const SizedBox(height: 10),
                Text(
                  'They\'ll get an email explaining how to sign in and find '
                  'their sessions.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
              if (widget.feedback.isNotEmpty) ...[
                const SizedBox(height: 30),
                const SectionHeader(title: 'Client feedback'),
                const SizedBox(height: 4),
                Text(
                  'Only the care team sees individual ratings. Clients see an '
                  'average once there are three.',
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
            '${therapist.upcomingSessions} upcoming · '
            '${therapist.completedSessions} completed',
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
                  '${rating.toStringAsFixed(1)} from '
                  '${therapist.profile.ratingCount}',
                  style: TextStyle(fontSize: 12, color: c.textMuted),
                ),
              ],
            ),
          ],
          const SizedBox(height: 6),
          Text(
            therapist.hasAccount
                ? 'Signed in as ${therapist.email}'
                : 'Hasn\'t signed in yet. They need to sign in to the app '
                    'with ${therapist.email} to see and join sessions.',
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
            item.clientLabel,
            style: TextStyle(fontSize: 12, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}
