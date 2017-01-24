# Change Log

## [Unreleased]
### Added
- Playback can be stopped after the current track finishes with the "Stop after current" menu item.

### Changed
- Clicking the menubar buttons now sends `NSWorkspaceDidActivateApplication` notifications to ensure [MediaKeyTap](https://github.com/nhurden/MediaKeyTap) switches kmbmpdc to most recently active application.
- ID3v2 cover art parsing changed to use [imeji](https://github.com/arttuperala/imeji).
- Notifications are displayed even if kmbmpdc is considered to be the active application.
- Track change notification is presented when playback is restarted after a stop.

### Fixed
- Application won't crash on start when libmpdclient is not installed locally.

[Unreleased]: https://github.com/arttuperala/kmbmpdc/compare/v1.0.0...HEAD
