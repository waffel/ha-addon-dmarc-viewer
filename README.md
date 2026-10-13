# DMARC Report Viewer add-on for Home Assistant

Home Assistant add-on that wraps [cry-inc/dmarc-report-viewer](https://github.com/cry-inc/dmarc-report-viewer).
It reads DMARC aggregate reports (XML, zip or gz attachments) from a folder of an IMAP mailbox and serves
a summary and a web UI. Everything stays on your network: no third-party report service is involved.

The add-on builds the viewer from source at a pinned upstream commit (see `COMMIT` in
`dmarc-viewer/Dockerfile`), so you review exactly what you run.

## Install

1. Home Assistant: Settings -> Add-ons -> Add-on store -> menu (three dots) -> Repositories.
2. Add `https://github.com/waffel/ha-addon-dmarc-viewer`.
3. Install "DMARC Report Viewer" (the first build compiles Rust and takes several minutes on a Raspberry Pi).
4. In the add-on configuration set `imap_host`, `imap_user`, `imap_password` and `imap_folder`, then start it.

Prepare the mailbox first: create a folder (default `DMARC-Reports`) and a mail filter that moves incoming
DMARC report mails (for example subject contains `Report domain`) into it.

## Sensors, alert and dashboard

The add-on hostname inside Home Assistant is `local-dmarc-viewer` for a local add-on and
`<repo-hash>-dmarc-viewer` for one installed from this repository. Check it on the add-on info page and adjust
the URLs in `examples/dmarc.yaml` if needed.

- `examples/dmarc.yaml`: REST sensors (reports, SPF passed, DKIM passed, flagged reports) and an automation that
  notifies you when the number of flagged reports increases. Place it at `/config/packages/dmarc.yaml`.
- `examples/dmarc-dashboard.yaml`: dashboard view with current values and a 30 day history.

## License

MIT, see `LICENSE`. The wrapped viewer is MIT licensed by its authors.
