import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../brand.dart';
import 'call_keep_alive.dart';
import 'session_format.dart';
import 'therapy_repository.dart';

class CallScreen extends StatefulWidget {
  static const routeName = '/call';

  const CallScreen({
    super.key,
    required this.counterpartName,
    required this.connect,
    this.keepAlive,
  });

  /// Who they're meeting — the therapist's name, or the client's first name.
  final String counterpartName;
  final Future<SessionCredentials> Function() connect;

  /// What holds the call together off-screen; injectable for tests.
  final CallKeepAlive? keepAlive;

  @override
  State<CallScreen> createState() => _CallScreenState();
}

enum _Phase { connecting, live, ended, failed }

class _CallScreenState extends State<CallScreen>
    with WidgetsBindingObserver {
  late final CallKeepAlive _keepAlive =
      widget.keepAlive ?? DeviceCallKeepAlive();
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

  /// The camera was on when the app went to the background, so it comes
  /// back on when the app does.
  bool _cameraPausedInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    unawaited(_teardown());
    super.dispose();
  }

  /// The camera can't be used from the background on either platform, and
  /// a track left running there fails rather than resuming. Release it on
  /// the way out and bring it back on the way in; the microphone stays on,
  /// which the foreground service (Android) and the audio background mode
  /// (iOS) allow.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_phase != _Phase.live) return;
    final participant = _room?.localParticipant;
    if (participant == null) return;
    switch (state) {
      case AppLifecycleState.paused when _cameraOn:
        _cameraPausedInBackground = true;
        unawaited(_setCamera(participant, false, onError: (e) {
          debugPrint('Camera release failed: $e');
        }));
      case AppLifecycleState.resumed when _cameraPausedInBackground:
        _cameraPausedInBackground = false;
        unawaited(_setCamera(participant, true, onError: (e) {
          debugPrint('Camera resume failed: $e');
          if (mounted) setState(() => _cameraOn = false);
        }));
      default:
        break;
    }
  }

  Future<void> _setCamera(
    LocalParticipant participant,
    bool on, {
    required void Function(Object error) onError,
  }) async {
    try {
      await participant.setCameraEnabled(on);
    } catch (e) {
      onError(e);
    }
  }

  Future<void> _teardown() async {
    final listener = _listener;
    final room = _room;
    _listener = null;
    _room = null;
    _cameraPausedInBackground = false;
    await _keepAlive.stop();
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

      // After the microphone and camera are on: Android 14 only lets the
      // service claim the types whose permissions are already granted.
      await _keepAlive.start(counterpartName: widget.counterpartName);

      _clock?.cancel();
      _clock = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
      if (!mounted) return;
      setState(() => _phase = _Phase.live);
      Sentry.metrics.count('therapy.call_joined', 1);
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
      // Dark in both modes, like any video call: light status-bar icons
      // whatever the app's appearance.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Pillars.black,
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
                    foregroundColor: Pillars.black,
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
                    color: Pillars.red,
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
      color: Pillars.black,
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
              color: color != null || active ? Colors.white : Pillars.black,
              semanticLabel: label,
            ),
          ),
        ),
      ),
    );
  }
}
