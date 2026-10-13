# DMARC Report Viewer

Reads DMARC aggregate reports from a folder of an IMAP mailbox and serves a summary and a web UI.

## Prepare the mailbox

1. Create a folder, for example `DMARC-Reports`.
2. Create a mail filter that moves incoming report mails into it (for example subject contains `Report domain`).

## Configuration

| Option | Default | Description |
|---|---|---|
| `imap_host` | `imap.mailbox.org` | IMAP server (TLS, port 993). |
| `imap_user` | | IMAP login name. |
| `imap_password` | | IMAP password. |
| `imap_folder` | `DMARC-Reports` | Folder that contains the report mails. |
| `check_interval_hours` | `24` | How often the folder is checked for new mails (1 to 168). |

## Access

The web UI listens on port 8080 inside Home Assistant's add-on network and is reachable from other add-ons and
Home Assistant core under the add-on hostname shown on the add-on info page. No port is published to the host.
Useful endpoints: `/summary`, `/dmarc-reports`, `/metrics`, `/health`.

See `examples/` in the repository for REST sensors, an alert automation and a dashboard view.
