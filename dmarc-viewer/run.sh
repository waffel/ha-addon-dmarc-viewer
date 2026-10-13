#!/bin/sh
# Maps the add-on options (Home Assistant writes them to /data/options.json) to the
# viewer's environment variables. The web UI is only reachable inside Home Assistant's
# internal add-on network (no host port is published), so basic auth is switched off.
set -eu
OPT=/data/options.json

IMAP_HOST="$(jq -r .imap_host "$OPT")"
IMAP_USER="$(jq -r .imap_user "$OPT")"
IMAP_PASSWORD="$(jq -r .imap_password "$OPT")"
IMAP_FOLDER="$(jq -r .imap_folder "$OPT")"
IMAP_CHECK_INTERVAL="$(( $(jq -r .check_interval_hours "$OPT") * 3600 ))"
export IMAP_HOST IMAP_USER IMAP_PASSWORD IMAP_FOLDER IMAP_CHECK_INTERVAL
export HTTP_SERVER_PASSWORD=""

exec dmarc-report-viewer
