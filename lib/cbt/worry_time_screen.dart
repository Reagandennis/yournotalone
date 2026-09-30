import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../brand.dart';
import '../toolkit/toolkit_ui.dart';
import 'cbt_content.dart';

/// A worry that's been parked until the worry window, and what became of it.
class ParkedWorry {
  ParkedWorry(this.text, {this.outcome});

  final String text;

  /// null while parked; 'plan' or 'let_go' once looked at.
  String? outcome;

  Map<String, dynamic> toJson() => {'text': text, 'outcome': outcome};

  static ParkedWorry fromJson(Map<String, dynamic> m) =>
      ParkedWorry(m['text'] as String, outcome: m['outcome'] as String?);
}

const _key = 'cbt.worries';

Future<List<ParkedWorry>> loadWorries() async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(_key);
  if (raw == null) return [];
  return [
    for (final m in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
      ParkedWorry.fromJson(m),
  ];
}

Future<void> saveWorries(List<ParkedWorry> worries) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _key,
    jsonEncode([for (final w in worries) w.toJson()]),
  );
}

/// Worry postponement. Through the day, worries get written down and
/// parked instead of chewed over. At a set window — fifteen minutes, with a
/// timer — each one is looked at once: something you can act on gets a
/// plan; the rest is let go. Most have gone quiet by then.
class WorryTimeScreen extends StatefulWidget {
  const WorryTimeScreen({
    super.key,
    this.windowLength = const Duration(minutes: 15),
  });

  final Duration windowLength;

  @override
  State<WorryTimeScreen> createState() => _WorryTimeScreenState();
}

class _WorryTimeScreenState extends State<WorryTimeScreen> {
  List<ParkedWorry>? _worries;
  final _input = TextEditingController();
  Timer? _timer;
  Duration? _left;

  @override
  void initState() {
    super.initState();
    loadWorries().then((w) {
      if (mounted) setState(() => _worries = w);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  bool get _inWindow => _left != null;

  void _park() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _worries!.insert(0, ParkedWorry(text));
      _input.clear();
    });
    saveWorries(_worries!);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Parked. It\'ll be here at worry time — you don\'t have '
            'to hold it now.',
          ),
        ),
      );
  }

  void _startWindow() {
    setState(() => _left = widget.windowLength);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _left! - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _endWindow(timeUp: true);
      } else {
        setState(() => _left = next);
      }
    });
  }

  void _endWindow({bool timeUp = false}) {
    _timer?.cancel();
    _timer = null;
    setState(() => _left = null);
    if (timeUp) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Time\'s up. Whatever\'s left can wait for tomorrow\'s '
              'window.',
            ),
          ),
        );
    }
  }

  void _decide(ParkedWorry worry, String outcome) {
    setState(() => worry.outcome = outcome);
    saveWorries(_worries!);
  }

  void _clearDone() {
    setState(() => _worries!.removeWhere((w) => w.outcome != null));
    saveWorries(_worries!);
  }

  String _clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _worryTile(ParkedWorry worry) {
    final decided = worry.outcome != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: toolkitCardColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              worry.text,
              style: TextStyle(
                fontSize: 14,
                color: decided ? Brand.textMuted : Brand.ink,
                height: 1.4,
                decoration: worry.outcome == 'let_go'
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            if (decided)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  worry.outcome == 'plan'
                      ? 'You\'ve got a plan for this one.'
                      : 'Let go — nothing to do here today.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cbtAccent,
                  ),
                ),
              )
            else if (_inWindow) ...[
              const SizedBox(height: 6),
              const Text(
                'Can you do something about it in the next week?',
                style: TextStyle(fontSize: 12.5, color: Brand.textMuted),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(worry, 'plan'),
                      child: const Text('Yes — plan it'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _decide(worry, 'let_go'),
                      child: const Text('No — let it go'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final worries = _worries;
    if (worries == null) {
      return const ToolkitScaffold(
        accent: cbtAccent,
        title: 'Worry window',
        children: [Center(child: CircularProgressIndicator())],
      );
    }
    final parked = worries.where((w) => w.outcome == null).length;
    return ToolkitScaffold(
      accent: cbtAccent,
      title: 'Worry window',
      children: [
        const ToolkitSection(
          title: 'Worry later, on purpose',
          subtitle:
              'You can\'t stop a worry arriving, but you can decide when '
              'to give it attention. Park it here as it comes. Then, once a '
              'day, open a fifteen-minute window and go through the list — '
              'and only then.',
        ),
        if (!_inWindow) ...[
          TextField(
            controller: _input,
            maxLength: 200,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => _park(),
            decoration: InputDecoration(
              labelText: 'What\'s on your mind right now?',
              counterText: '',
              suffixIcon: IconButton(
                icon: const Icon(Icons.local_parking_rounded),
                tooltip: 'Park it',
                onPressed: _park,
              ),
            ),
          ),
          const SizedBox(height: 18),
          ToolkitNote(
            tint: const Color(0x143764CD),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parked == 0
                            ? 'Nothing parked'
                            : '$parked parked for worry time',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Brand.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Best kept to the same time each day — not the '
                        'hour before bed.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Brand.textMuted,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: parked == 0 ? null : _startWindow,
                  // Sized to its label: the theme's buttons stretch full
                  // width, which a Row can't give.
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Open window'),
                ),
              ],
            ),
          ),
        ] else ...[
          ToolkitNote(
            tint: const Color(0x14C53C26),
            child: Row(
              children: [
                Text(
                  _clock(_left!),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    color: Brand.ink,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    'Go through each worry once. Decide, don\'t dwell.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Brand.textMuted,
                      height: 1.4,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _endWindow(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        if (worries.isNotEmpty) ...[
          Row(
            children: [
              const Expanded(child: ToolkitSection(title: 'Your list')),
              if (worries.any((w) => w.outcome != null))
                TextButton(
                  onPressed: _clearDone,
                  child: const Text(
                    'Clear decided',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
            ],
          ),
          for (final w in worries) _worryTile(w),
        ] else
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Your parked worries appear here. Most people find half of them '
              'have lost their sting by the time the window opens.',
              style: TextStyle(
                fontSize: 13,
                color: Brand.textMuted,
                height: 1.5,
              ),
            ),
          ),
      ],
    );
  }
}
