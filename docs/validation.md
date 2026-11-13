# Validation

Initial implementation: 16 November 2026. Commit dates record the actual work.

## Verified locally

- 14 Python tests: LRC parsing, simultaneous cues, Unicode, metadata matching,
  recording mismatches, provider fallback, instrumental tracks, network failures,
  rate limiting, URL encoding, input bounds, and redirect refusal.
- Qt Quick tests: cue boundaries, backward seeking, player selection, time
  formatting, reader buttons, and rendering at 440×650 and 360×430.
- Six Quickshell session assertions: stale replies, malformed output, cooldowns,
  and seek-dependent highlighting.
- A real Python subprocess with synthetic data: switching tracks during lookup
  ignores the old result and displays the new one.
- Omarchy manifest validation and a component-load check using the installed
  `qs.Ui` and `qs.Commons` modules in a temporary harness.
- The full and compact reader screenshots were visually inspected.

## Still requires a desktop session

This development environment cannot access the live session's Wayland/D-Bus
sockets or resolve internet hosts from the terminal. Offscreen checks therefore
do not establish live player detection, real provider responses, compositor
window placement, or bar popup behavior on multiple monitors.

Before treating this release as desktop-validated:

1. Install alongside existing plugins and open the bar popup.
2. Play, pause, seek, and change tracks in your usual player.
3. Check a synchronized recording, a plain-lyrics recording, and a missing song.
4. Open the separate window, resize it, drag its header, close it, and reopen it.
5. Switch between two players and confirm the selected player stays selected.
6. Scroll manually, resume following, and adjust timing.
7. Disconnect internet access and confirm a retryable error appears.
8. Disable or remove only `akash.sing-with-omarchy` if rolling back.

The existing installed lyrics plugin was not changed during development.

## Interface references

- Installed Omarchy shell README and plugin manifest documentation.
- [Quickshell MPRIS interface](https://quickshell.org/docs/v0.2.0/types/Quickshell.Services.Mpris/MprisPlayer/).
- [LRCLIB API](https://lrclib.net/docs).
- [Lyrics.ovh API](https://github.com/NTag/lyrics.ovh/blob/main/apiary.apib).
