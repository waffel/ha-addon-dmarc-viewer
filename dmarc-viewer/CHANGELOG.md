# Changelog

All notable changes to this repository are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Home Assistant add-on wrapping cry-inc/dmarc-report-viewer, built from the pinned upstream commit `5e53bf8`.
- The add-on reads DMARC reports from an IMAP folder and publishes `sensor.dmarc_reports_total`,
  `sensor.dmarc_spf_passed`, `sensor.dmarc_dkim_passed` and `sensor.dmarc_reports_flagged` to Home Assistant itself.
  The sensors wait for the first completed mailbox check instead of publishing zeros.
- Options: `imap_host`, `imap_user`, `imap_password`, `imap_folder`, `check_interval_hours` (default 24),
  `web_ui_password` and `language` (`en`, `de`). The add-on refuses to start until host, user and password are set.
- Optional web UI port (off by default).
- Dashboard card in English and German, an alert blueprint, add-on icon and logo, and a README screenshot.
- Tests for the add-on scripts, the documentation and the release notes extractor, run in CI together with lint and an image build.
- Release workflow: pushing a `vX.Y.Z` tag on `main` creates a GitHub release from this changelog.
- Dependabot for GitHub Actions and the Dockerfile base images.
