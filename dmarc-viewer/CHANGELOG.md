# Changelog

All notable changes to this repository are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Home Assistant add-on wrapping cry-inc/dmarc-report-viewer, built from a pinned upstream commit.
- Option `check_interval_hours` (default 24) for how often the mailbox is checked.
- Examples: REST sensors, alert automation and dashboard view.
- Add-on icon and logo (sources in `assets/`).

### Changed
- `imap_host` has no default any more and the add-on refuses to start until host, user and password are set.
