# Changelog

All notable changes to the **When R U Free** project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Detailed per-release documentation is archived in the [`docs/changelog/`](docs/changelog/README.md) directory.

---

## [1.0.0] - 2026-09-10

### Added
- **Local-First Availability Engine:** Pure Dart computation (`AvailabilityService`) for interval carving, boundary merging, mutual group intersection, and weekly meetup ranking.
- **Manual Timetable Editor:** 7-day Monday–Sunday tabs with start/end time pickers, conflict warnings, swipe-to-delete, and sample data generator.
- **Microsoft 365 / Outlook Import:** Read-only calendar import via OAuth 2.0 PKCE (`Calendars.Read`), automatic timezone conversion, multi-day class splitting, deduplication, and a demo preview mode.
- **Home Live Dashboard:** Real-time friends-free-now status chips with individual "till HH:MM" countdowns, next all-free break card, and ranked weekly suggestions.
- **Proportional Week Timeline:** Adaptive free block scaling, compact skip dividers for busy periods, and full-group highlights.
- **Shared Break Drill-Down:** Inspect members free vs in class, one-tap copy formatted plan for group chat, and quick busy override creation.
- **"I'm Actually Busy Then" Overrides:** One-off calendar date overrides (`BusyBlock`) that carve time out of shared breaks without touching the weekly timetable.
- **Offline P2P Sharing:** Encode/decode timetables into versioned Base64URL codes (`WRF1-...`), live high-density QR code generation, camera QR scanning via `mobile_scanner`, and text-code copy-pasting.
- **Offline Group Management:** Name-based friends list, include/exclude toggle switches, manual friend timetable editor, and developer demo friend presets.
- **On-Device Gap Alerts:** Background notification scheduling (`flutter_local_notifications`) with configurable advance warnings (0–30 min) and test alert verification.
- **Backup & Restore:** Full JSON export/import and data wipe capabilities.
- **Comprehensive Test Suite:** 58 unit and widget tests with 100% pass rate.
- **Companion Server:** Optional Express server in `server/` with `/health` and `/api/overlap`.
- **License Update:** Licensed under the [PolyForm Small Business License 1.0.0](LICENSE.md).

[1.0.0]: https://github.com/PenguinBTW/When-R-U-Free/releases/tag/v1.0.0
