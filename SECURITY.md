# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private vulnerability reporting
("Security" tab -> "Report a vulnerability") on this repository.

## Scope

This repository only packages [cry-inc/dmarc-report-viewer](https://github.com/cry-inc/dmarc-report-viewer) as a
Home Assistant add-on. Vulnerabilities in the viewer itself belong to the upstream project.

## Design notes

- The viewer is compiled from a pinned upstream commit (`COMMIT` in `dmarc-viewer/Dockerfile`), not downloaded as a binary.
- The web UI has no published host port and is only reachable inside Home Assistant's internal add-on network.
- The IMAP password is stored in the add-on options (type `password`) and never written to this repository.
