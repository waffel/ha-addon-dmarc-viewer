#!/bin/sh
# Maps the add-on options (Home Assistant writes them to /data/options.json) to the
# viewer's environment variables, starts the sensor publisher and then the viewer.
set -eu
OPT=/data/options.json

IMAP_HOST="$(jq -r .imap_host "$OPT")"
IMAP_USER="$(jq -r .imap_user "$OPT")"
IMAP_PASSWORD="$(jq -r .imap_password "$OPT")"
IMAP_FOLDER="$(jq -r .imap_folder "$OPT")"
IMAP_CHECK_INTERVAL="$(( $(jq -r .check_interval_hours "$OPT") * 3600 ))"
# An empty password switches the web UI's basic auth off. That is fine while the port stays unpublished.
HTTP_SERVER_PASSWORD="$(jq -r '.web_ui_password // ""' "$OPT")"
DMARC_LANGUAGE="$(jq -r '.language // "en"' "$OPT")"
export IMAP_HOST IMAP_USER IMAP_PASSWORD IMAP_FOLDER IMAP_CHECK_INTERVAL HTTP_SERVER_PASSWORD DMARC_LANGUAGE

: "${IMAP_HOST:?Option imap_host is empty. Set it in the add-on configuration.}"
: "${IMAP_USER:?Option imap_user is empty. Set it in the add-on configuration.}"
: "${IMAP_PASSWORD:?Option imap_password is empty. Set it in the add-on configuration.}"

/push-states.sh &
exec dmarc-report-viewer
