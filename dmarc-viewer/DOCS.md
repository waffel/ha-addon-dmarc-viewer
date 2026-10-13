# DMARC Report Viewer

Reads [DMARC](https://dmarc.org/overview/) aggregate reports from a folder of an IMAP mailbox and publishes the
results as Home Assistant sensors.

## Prepare the mailbox

1. Create a folder, for example `DMARC-Reports`.
2. Create a mail filter on the server that moves incoming report mails into it (for example subject contains
   `Report domain`). A server-side filter works while your devices are off; a rule in a mail app does not.

## Configuration

| Option | Default | Description |
|---|---|---|
| `imap_host` | (empty, required) | Host name of your IMAP server (TLS, port 993). |
| `imap_user` | (empty, required) | IMAP login name. |
| `imap_password` | (empty, required) | IMAP password. |
| `imap_folder` | `DMARC-Reports` | Folder with the report mails. A sub-folder of the inbox is usually written `INBOX/Name` or `INBOX.Name`, depending on the server. |
| `check_interval_hours` | `24` | How often the folder is checked for new mails (1 to 168). |
| `web_ui_password` | (empty) | Optional password for the viewer's web page, user name `dmarc`. |

## Sensors

The add-on creates these sensors in Home Assistant and refreshes them every 10 minutes:

| Sensor | Meaning |
|---|---|
| `sensor.dmarc_reports_total` | Number of parsed reports |
| `sensor.dmarc_spf_passed` | Evaluations where SPF passed |
| `sensor.dmarc_dkim_passed` | Evaluations where DKIM passed |
| `sensor.dmarc_reports_flagged` | Reports in which SPF, DKIM or DMARC failed |

After a Home Assistant restart the sensors are missing until the add-on's next refresh (at most 10 minutes).

## Dashboard card

Copy this into Dashboard -> Edit -> Add card -> Manual:

```yaml
type: vertical-stack
cards:
  - type: entities
    title: DMARC reports
    entities:
      - entity: sensor.dmarc_reports_total
        name: Reports total
      - entity: sensor.dmarc_spf_passed
        name: SPF passed
      - entity: sensor.dmarc_dkim_passed
        name: DKIM passed
      - entity: sensor.dmarc_reports_flagged
        name: Flagged reports
  - type: history-graph
    title: History, last 30 days
    hours_to_show: 720
    entities:
      - entity: sensor.dmarc_spf_passed
        name: SPF passed
      - entity: sensor.dmarc_dkim_passed
        name: DKIM passed
      - entity: sensor.dmarc_reports_flagged
        name: Flagged reports
```

For an alert, import the [blueprint](https://github.com/waffel/ha-addon-dmarc-viewer/blob/main/blueprints/automation/dmarc_flagged_alert.yaml).
Details are in the [repository README](https://github.com/waffel/ha-addon-dmarc-viewer#readme).

## Web UI (optional)

The viewer has a web page with all reports. It is off by default. To use it, set `web_ui_password`, then enable
port 8080 in the add-on's Network tab and use "Open Web UI". Without a password, anyone on your network could read it.
