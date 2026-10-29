# Stoa handoff — 2026-10-29 06:00 CT

Session stopped on the Claude usage limit (resets 9am CT). State:

## Done
- Toolchain: REA 6.8.0 + Ghidra 12.1.4 (locally built macOS natives) + JDK 25; driver in `tools/rea/driver.mjs`, helper `tools/rea/q`.
- Repo: SwiftPM modules StoaCore (13 SwiftData models, store, workspace actions) and StoaWeb (data stores, blocker compiler, tab web view, address resolver), XcodeGen app target, CI green, 19 tests.
- Spec: `docs/spec/00-data-model.md` draft v1 (needs corrections below).
- Evidence notes (gitignored, in `analysis/`): notes-address-search-find.md notes-blocking.md notes-history-bookmarks-downloads-permissions.md notes-import.md notes-media.md notes-profiles-incognito.md notes-spaces.md notes-sync-settings-shortcuts.md notes-tabs-sidebar.md 

## Evidence notes still missing (agents died on the limit)
collections, split view, extensions, passwords, gating-and-shell. Their traces and digests exist in `analysis/` (`q-tf-*.json`, `digest-*.md`); re-run the notes step for those five.

## Corrections owed to 00-data-model.md (from the notes)
- "Profile" is two things: identity profile (Core Data) vs cookie-jar browsing profile (JSON store) with modes Shared Everywhere / Separate per Space / Custom. Spaces hold no profile attribute.
- Download statuses: pending, downloading, paused, completed, failed, cancelled, missing.
- Settings categories: general, appearance, privacy, security, downloads, advanced, experimental.
- Collections and per-space wallpaper are NOT entities: collections.json file; wallpaper = settings rows (`bg_*` keys).
- Store has Cloud (bookmarks, folders, history, settings, profile, permissions, rules, notes) and Local (tab, space, session, split, download) configurations; sync opt-in, off by default.

## Next steps
1. Re-run the five missing evidence notes (Sonnet agents, AGENT-BRIEF.md in analysis/). Do NOT call open_binary; it restarts Ghidra's 30-min import.
2. Write docs/spec/01–15 from the notes (clean-room: behavior only; blocker domain lists from EasyList, not theirs).
3. Fix 00-data-model.md per the corrections, then adjust StoaCore models (BrowsingProfile store, DownloadStatus, Cloud/Local split).
4. Milestone 1 UI: shell, sidebar (260–480 pt, rail mode), tab strip, address bar.
