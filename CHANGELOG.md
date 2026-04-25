# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows semantic versioning.

## [Unreleased]

## [1.1.2] - 2026-04-25

### Added
- Menu bar display name settings for Claude and Codex, limited to 7 characters each

## [1.1.1] - 2026-04-25

### Added
- Remaining percentage display options for the menu bar and popover (Thank you @cifilter)

## [1.1.0] - 2026-04-07

### Added
- Menu bar display mode that shows both usage percentages and pacing insight in the status item

## [1.0.1] - 2026-04-07

### Added
- Launch at startup option in the settings window

### Changed
- The project no longer publishes a GitHub Release workflow
- README now documents building a DMG with the current app version by default
- DMG builds now clear stale Swift module caches before release builds

## [1.0.0] - 2026-04-06

### Added
- First public release of AIPace for macOS
- Menu bar usage display for Claude and Codex `5h` and `weekly` windows
- Main popover with provider cards, pacing insights, refresh controls, and notifications
- Settings window for language, auto refresh, notification sound, menu bar display mode, and custom provider colors
- README screenshots and DMG-based install instructions

## [0.1.0] - 2026-04-06

### Added
- Initial app packaging and release workflow groundwork
