import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/auth_ui.dart';
import '../brand.dart';

/// Edit profile: name and profile picture.
///
/// The photo is uploaded to the public `avatars` bucket at
/// `<user-id>/avatar.jpg` (migration 0005) and its public URL — with a
/// cache-busting `?v=` — is kept in auth metadata as `avatar_url`,
/// alongside the existing `full_name`.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late final TextEditingController _name;

  Uint8List? _pickedBytes; // newly chosen photo, not yet uploaded
  bool _removePhoto = false; // remove the current photo on save
  bool _saving = false;

  SupabaseClient get _client => Supabase.instance.client;

  String? get _currentAvatarUrl {
    final url =
        _client.auth.currentUser?.userMetadata?['avatar_url'] as String?;
    return (url == null || url.isEmpty) ? null : url;
  }

  bool get _hasPhoto =>
      _pickedBytes != null || (!_removePhoto && _currentAvatarUrl != null);

  @override
  void initState() {
    super.initState();
    final meta = _client.auth.currentUser?.userMetadata;
    _name = TextEditingController(
      text: (meta?['full_name'] as String?)?.trim() ?? '',
    );
    // The initial-letter fallback avatar tracks the name as it's typed.
    _name.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 82,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _pickedBytes = bytes;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(source == ImageSource.camera
              ? 'The camera isn\'t available right now.'
              : 'Couldn\'t open your photo library.'),
        ),
      );
    }
  }

  void _showPhotoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Brand.textMuted),
                title: const Text('Choose from library',
                    style: TextStyle(fontSize: 14.5, color: Brand.ink)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pick(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined,
                    color: Brand.textMuted),
                title: const Text('Take a photo',
                    style: TextStyle(fontSize: 14.5, color: Brand.ink)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _pick(ImageSource.camera);
                },
              ),
              if (_hasPhoto)
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline_rounded, color: Brand.red),
                  title: const Text('Remove photo',
                      style: TextStyle(fontSize: 14.5, color: Brand.red)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    setState(() {
                      _pickedBytes = null;
                      _removePhoto = true;
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      final uid = _client.auth.currentUser?.id;
      if (uid == null) throw StateError('Not signed in');
      final path = '$uid/avatar.jpg';
      String? avatarUrl = _removePhoto ? null : _currentAvatarUrl;

      if (_pickedBytes != null) {
        await _client.storage.from('avatars').uploadBinary(
              path,
              _pickedBytes!,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: true,
              ),
            );
        // The path is stable across uploads, so bust the image cache.
        final publicUrl = _client.storage.from('avatars').getPublicUrl(path);
        avatarUrl = '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';
      } else if (_removePhoto && _currentAvatarUrl != null) {
        await _client.storage.from('avatars').remove([path]);
      }

      await _client.auth.updateUser(
        UserAttributes(data: {
          'full_name': _name.text.trim(),
          'avatar_url': avatarUrl,
        }),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.of(context).pop(true);
    } on StorageException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Couldn\'t save your photo: ${e.message}')),
        );
    } catch (e) {
      if (mounted) showAuthError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatar() {
    final name = _name.text.trim();
    final initial =
        name.isEmpty ? '?' : name.characters.first.toUpperCase();

    Widget inner;
    if (_pickedBytes != null) {
      inner = Image.memory(_pickedBytes!, fit: BoxFit.cover);
    } else if (!_removePhoto && _currentAvatarUrl != null) {
      inner = Image.network(
        _currentAvatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _initialAvatar(initial),
      );
    } else {
      inner = _initialAvatar(initial);
    }

    return Center(
      child: GestureDetector(
        onTap: _saving ? null : _showPhotoSheet,
        child: Stack(
          children: [
            Container(
              width: 112,
              height: 112,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0x143764CD),
                shape: BoxShape.circle,
                border: Border.all(color: Brand.border, width: 1.2),
              ),
              child: inner,
            ),
            Positioned(
              right: 0,
              bottom: 4,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Brand.ink,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initialAvatar(String initial) {
    return Center(
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 38,
          fontWeight: FontWeight.w600,
          color: Brand.blue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = _client.auth.currentUser?.email;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 32),
                children: [
                  _avatar(),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: _saving ? null : _showPhotoSheet,
                      child: Text(_hasPhoto ? 'Change photo' : 'Add a photo'),
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthTextField(
                    controller: _name,
                    label: 'Your name',
                    icon: Icons.person_outline_rounded,
                    textInputAction: TextInputAction.done,
                    validator: (value) =>
                        (value?.trim().isEmpty ?? true) ? 'Enter your name' : null,
                  ),
                  if (email != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Brand.border, width: 1.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mail_outline_rounded,
                              size: 21, color: Brand.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Brand.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Text(
                        'Your email can\'t be changed here.',
                        style:
                            TextStyle(fontSize: 12, color: Brand.textMuted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  AuthSubmitButton(
                    label: 'Save changes',
                    loading: _saving,
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
