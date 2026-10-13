# Security policy

## Reporting a vulnerability

Please do not open a public issue for security problems. Use GitHub's private vulnerability reporting
("Security" tab -> "Report a vulnerability") on this repository.

## Scope

This repository only packages [cry-inc/dmarc-report-viewer](https://github.com/cry-inc/dmarc-report-viewer) as a
Home Assistant add-on. Vulnerabilities in the viewer itself belong to the upstream project.

## Design notes

- The viewer is compiled from a pinned upstream commit (`COMMIT` in `dmarc-viewer/Dockerfile`), not downloaded as a binary.
- The viewer parses mail attachments from strangers, so it runs as the unprivileged user `nobody` and does not see the
  Supervisor token. Only the small script that publishes the sensors has the token, and it passes it to `curl` through
  stdin, never as a command line argument.
- The Supervisor watchdog restarts the add-on when the viewer stops answering on `/health`.
- CI scans for secrets (gitleaks, including the git history) and for misconfigurations (trivy), and reports known
  vulnerabilities of the built image. Reviewed and accepted findings are listed with reasons in `.trivyignore`.
- The web UI has no published host port and is only reachable inside Home Assistant's internal add-on network.
- The IMAP password is stored in the add-on options (type `password`) and never written to this repository.
