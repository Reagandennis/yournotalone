# Voice guides

Recorded narration for the guided meditations. To add one:

1. Record the session at its full length (Body scan is 12 minutes, so the
   file runs 12 minutes), with silence between lines. Export as `.m4a`
   (AAC, mono, 64–96 kbps keeps a 12-minute file around 6–8 MB).
2. Save it here, e.g. `assets/narration/body_scan.m4a`.
3. In `lib/meditation/meditation_catalog.dart`, give that meditation
   `narration: 'assets/narration/body_scan.m4a',`.

The session then shows a "Voice" chip and plays the recording. It pauses
when the session pauses, and the on-screen lines keep showing, so the
session still works with the sound off.
