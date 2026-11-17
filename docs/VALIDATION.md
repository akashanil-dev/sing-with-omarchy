
### Center bar lyrics (2026-11-17, Omarchy 4.0.6-1)

- Python: 25 checks passed; QtTest: 18 checks passed; session, worker-race,
  and installed Omarchy type-loading harnesses passed.
- Live Spotify playback: center lyric visible; `centerStatus` reported active,
  supported, and 663.25 logical pixels of available width on this monitor.
- Captured enabled and disabled bar states; original clock, caffeine, update,
  and pomodoro widgets returned when disabled.
- Compared shell.json against the pre-change backup: only this plugin's
  `centerLyrics` setting changed; widget order and all other settings matched.
- Enabled preference survived a shell restart. No system update performed.
- Omarchy 4.5 compatibility still requires verification after the upgrade.
