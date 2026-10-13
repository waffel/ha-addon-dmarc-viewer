# Changelog

All notable changes to this repository are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- Home Assistant add-on wrapping cry-inc/dmarc-report-viewer, built from a pinned upstream commit.
- Option `check_interval_hours` (default 24) for how often the mailbox is checked.
- The add-on publishes `sensor.dmarc_*` to Home Assistant itself, no YAML needed.
- Optional web UI port (off by default) with `web_ui_password`.
- Sensors wait for the first completed mailbox check instead of publishing zeros.
- Dashboard card (also shown in the add-on documentation) and an alert blueprint.
- Add-on icon and logo (sources in `assets/`).

### Changed
- Removed the REST sensor examples; the add-on creates the sensors.
- `imap_host` has no default any more and the add-on refuses to start until host, user and password are set.
