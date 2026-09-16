import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../brand.dart';
import 'session_format.dart';
import 'therapy_repository.dart';

class CallScreen extends StatefulWidget {
  const CallScreen({
    super.key,
    required this.counterpartName,
    required this.connect,
  });

  /// Who they're meeting — the therapist's name, or the client's first name.
  final String counterpartName;
  final Future<SessionCredentials> Function() connect;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Phase { connecting, live, ended, failed }

class _CallScreenState extends State<CallScreen> {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  Timer? _clock;
  _Phase _phase = _Phase.connecting;
  String? _error;
  DateTime? _endsAt;
  bool _micOn = true;
  bool _cameraOn = true;
  CameraPosition _cameraPosition = CameraPosition.front;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _clock?.cancel();
    unawaited(_teardown());
    super.dispose();
  }

  Future<void> _teardown() async {
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    await listener?.dispose();
    await room?.disconnect();
    await room?.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _start() async {
    setState(() {
      _phase = _Phase.connecting;
      _error = null;
    });
    await _teardown();
    try {
      final credentials = await widget.connect();
      if (!mounted) return;

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      final listener = room.createListener()
        ..on<ParticipantConnectedEvent>((_) => _refresh())
        ..on<ParticipantDisconnectedEvent>((_) => _refresh())
        ..on<TrackSubscribedEvent>((_) => _refresh())
        ..on<TrackUnsubscribedEvent>((_) => _refresh())
        ..on<TrackMutedEvent>((_) => _refresh())
        ..on<TrackUnmutedEvent>((_) => _refresh())
        ..on<LocalTrackPublishedEvent>((_) => _refresh())
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted && !_leaving) setState(() => _phase = _Phase.ended);
        });
      _room = room;
      _listener = listener;
      _endsAt = credentials.endsAt;

      await room.connect(credentials.url, credentials.token);

      // A blocked camera shouldn't cost them the session: carry on with
      // whatever works and say what doesn't.
      final missing = <String>[];
      try {
        await room.localParticipant?.setMicrophoneEnabled(true);
        _micOn = true;
      } catch (e) {
        debugPrint('Microphone unavailable: $e');
        _micOn = false;
        missing.add('microphone');
      }
      try {
        await room.localParticipant?.setCameraEnabled(true);
        _cameraOn = true;
      } catch (e) {
        debugPrint('Camera unavailable: $e');
        _cameraOn = false;
        missing.add('camera');
      }

      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
      if (!mounted) return;
      setState(() => _phase = _Phase.live);
      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Your ${missing.join(' and ')} isn\'t available. You can allow '
              'it in your phone\'s settings for this app.',
            ),
          ),
        );
      }
    } on SessionAccessException catch (e) {
      _fail(e.message);
    } on StateError {
      _fail('You\'ve been signed out. Please log in again.');
    } catch (e) {
      debugPrint('Joining the session failed: $e');
      _fail('Couldn\'t connect to the session — check your connection and '
          'try again.');
    }
  }

  void _fail(String message) {
    unawaited(_teardown());
    if (!mounted) return;
    setState(() {
      _phase = _Phase.failed;
      _error = message;
    });
  }

  Future<void> _leave() async {
    _leaving = true;
    _clock?.cancel();
    await _teardown();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _toggleMic() async {
    final next = !_micOn;
    try {
      await _room?.localParticipant?.setMicrophoneEnabled(next);
      setState(() => _micOn = next);
    } catch (e) {
      debugPrint('Microphone toggle failed: $e');
    }
  }

  Future<void> _toggleCamera() async {
    final next = !_cameraOn;
    try {
      await _room?.localParticipant?.setCameraEnabled(next);
      setState(() => _cameraOn = next);
    } catch (e) {
      debugPrint('Camera toggle failed: $e');
    }
  }

  Future<void> _flipCamera() async {
    final track = _videoOf(_room?.localParticipant);
    if (track is! LocalVideoTrack) return;
    final next = _cameraPosition == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;
    try {
      await track.setCameraPosition(next);
      setState(() => _cameraPosition = next);
    } catch (e) {
      debugPrint('Camera flip failed: $e');
    }
  }

  VideoTrack? _videoOf(Participant? participant) {
    if (participant == null) return null;
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted) return track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _phase != _Phase.live,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Brand.ink,
        body: switch (_phase) {
          _Phase.connecting => _message(
              icon: null,
              title: 'Connecting to your session…',
              detail: null,
            ),
          _Phase.failed => _message(
              icon: Icons.videocam_off_rounded,
              title: 'Couldn\'t join',
              detail: _error,
              primary: ('Try again', _start),
            ),
          _Phase.ended => _message(
              icon: Icons.call_end_rounded,
              title: 'The call has ended',
              detail: 'If you were cut off, you can rejoin while the '
                  'session is still on.',
              primary: ('Rejoin', _start),
            ),
          _Phase.live => _live(),
        },
      ),
    );
  }

  Widget _message({
    required IconData? icon,
    required String title,
    required String? detail,
    (String, VoidCallback)? primary,
  }) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon == null)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: Colors.white,
                  ),
                )
              else
                Icon(icon, size: 42, color: Colors.white70),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 8),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (primary != null)
                ElevatedButton(
                  onPressed: primary.$2,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Brand.ink,
                  ),
                  child: Text(primary.$1),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _live() {
    final room = _room;
    final remote = room?.remoteParticipants.values.firstOrNull;
    final remoteVideo = _videoOf(remote);
    final localVideo = _cameraOn ? _videoOf(room?.localParticipant) : null;
    final endsAt = _endsAt;
    final status = remote == null
        ? 'Waiting for ${widget.counterpartName} to join…'
        : endsAt == null
            ? 'Connected'
            : 'Session ends at ${formatTime(endsAt)}';

    return Stack(
      children: [
        Positioned.fill(
          child: remoteVideo != null
              ? VideoTrackRenderer(remoteVideo, fit: VideoViewFit.cover)
              : _placeholder(remote != null),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 150, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.counterpartName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (localVideo != null)
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 108,
                    height: 150,
                    child: VideoTrackRenderer(
                      localVideo,
                      fit: VideoViewFit.cover,
                    ),
                  ),
                ),
              ),
            ),
          ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Wrap(
                spacing: 16,
                children: [
                  _control(
                    icon: _micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                    label: _micOn ? 'Mute' : 'Unmute',
                    active: _micOn,
                    onTap: _toggleMic,
                  ),
                  _control(
                    icon: _cameraOn
                        ? Icons.videocam_rounded
                        : Icons.videocam_off_rounded,
                    label: _cameraOn ? 'Turn camera off' : 'Turn camera on',
                    active: _cameraOn,
                    onTap: _toggleCamera,
                  ),
                  _control(
                    icon: Icons.cameraswitch_rounded,
                    label: 'Switch camera',
                    active: true,
                    onTap: _cameraOn ? _flipCamera : null,
                  ),
                  _control(
                    icon: Icons.call_end_rounded,
                    label: 'Leave',
                    active: true,
                    color: Brand.red,
                    onTap: _leave,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder(bool joined) {
    final name = widget.counterpartName.trim();
    return ColoredBox(
      color: Brand.ink,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: const BoxDecoration(
                color: Color(0x33FFFFFF),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              joined ? 'Camera is off' : 'Not here yet',
              style: const TextStyle(fontSize: 13.5, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  Widget _control({
    required IconData icon,
    required String label,
    required bool active,
    required VoidCallback? onTap,
    Color? color,
  }) {
    return Tooltip(
      message: label,
      child: Material(
        color: color ?? (active ? const Color(0x33FFFFFF) : Colors.white),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 58,
            height: 58,
            child: Icon(
              icon,
              size: 26,
              color: color != null || active ? Colors.white : Brand.ink,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}
