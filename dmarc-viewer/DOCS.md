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
| `language` | `en` | Language of the sensor names in Home Assistant: `en` or `de`. |

## Sensors

The add-on creates these sensors in Home Assistant and refreshes them every 10 minutes. They all use the same blank unit,
so that Home Assistant draws them together in one history chart. The sensor names tell what is counted:

| Sensor | Meaning |
|---|---|
| `sensor.dmarc_reports_total` | Number of parsed reports (one report file per sender and day) |
| `sensor.dmarc_spf_passed` | Number of mails for which SPF passed (summed over all reports) |
| `sensor.dmarc_dkim_passed` | Number of mails for which DKIM passed (summed over all reports) |
| `sensor.dmarc_reports_flagged` | Reports in which SPF, DKIM or DMARC failed |

After a Home Assistant restart the sensors are missing until the add-on's next refresh (at most 10 minutes).

## Dashboard card

Copy this into Dashboard -> Edit -> Add card -> Manual (a [German version](https://github.com/waffel/ha-addon-dmarc-viewer/blob/main/examples/dashboard-card.de.yaml) is in the repository):

```yaml
type: vertical-stack
cards:
  - type: entities
    title: DMARC reports
    entities:
      - sensor.dmarc_reports_total
      - sensor.dmarc_spf_passed
      - sensor.dmarc_dkim_passed
      - sensor.dmarc_reports_flagged
  - type: history-graph
    title: History, last 30 days
    hours_to_show: 720
    entities:
      - sensor.dmarc_spf_passed
      - sensor.dmarc_dkim_passed
      - sensor.dmarc_reports_flagged
```

For an alert, import the [blueprint](https://github.com/waffel/ha-addon-dmarc-viewer/blob/main/blueprints/automation/dmarc_flagged_alert.yaml).
Details are in the [repository README](https://github.com/waffel/ha-addon-dmarc-viewer#readme).

## Web UI (optional)

The viewer has a web page with all reports. It is off by default. To use it, set `web_ui_password`, then enable
port 8080 in the add-on's Network tab and use "Open Web UI". Without a password, anyone on your network could read it.
