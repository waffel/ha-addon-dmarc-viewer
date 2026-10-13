#!/bin/sh
# Reads the viewer's summary and publishes it as Home Assistant sensors (sensor.dmarc_*),
# using the add-on's Supervisor token. Runs next to the viewer inside the same container.
# Secrets (Supervisor token, web UI password) are handed to curl through its config on stdin,
# never as command line arguments.
# Environment (all optional, defaults fit the add-on): VIEWER_URL, HA_API, PUSH_INTERVAL (seconds),
# RETRY_INTERVAL (seconds), PUSH_ONCE (set to run a single round), HTTP_SERVER_USER, HTTP_SERVER_PASSWORD,
# DMARC_LANGUAGE (en or de).
set -u

VIEWER_URL="${VIEWER_URL:-http://127.0.0.1:8080}"
HA_API="${HA_API:-http://supervisor/core/api}"
PUSH_INTERVAL="${PUSH_INTERVAL:-600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-30}"

if [ -z "${SUPERVISOR_TOKEN:-}" ]; then
    echo "SUPERVISOR_TOKEN is not set, cannot publish sensors." >&2
    exit 1
fi

BODY_FILE="$(mktemp)"
trap 'rm -f "$BODY_FILE"' EXIT

# Escapes a value for use inside a double-quoted curl config string.
curl_escape() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

viewer_get() {
    if [ -n "${HTTP_SERVER_PASSWORD:-}" ]; then
        printf 'user = "%s:%s"\n' "$(curl_escape "${HTTP_SERVER_USER:-dmarc}")" "$(curl_escape "$HTTP_SERVER_PASSWORD")" |
            curl -fsS -K - "$VIEWER_URL$1"
    else
        curl -fsS "$VIEWER_URL$1"
    fi
}

# Entity names and units follow the add-on option "language" (en or de).
if [ "${DMARC_LANGUAGE:-en}" = "de" ]; then
    NAME_TOTAL="DMARC-Berichte erhalten"
    NAME_SPF="DMARC-Mails mit SPF bestanden"
    NAME_DKIM="DMARC-Mails mit DKIM bestanden"
    NAME_FLAGGED="DMARC-Berichte auffällig"
    UNIT_REPORTS="Berichte"
    UNIT_MAILS="Mails"
else
    NAME_TOTAL="DMARC reports received"
    NAME_SPF="DMARC mails passing SPF"
    NAME_DKIM="DMARC mails passing DKIM"
    NAME_FLAGGED="DMARC reports flagged"
    UNIT_REPORTS="reports"
    UNIT_MAILS="mails"
fi

# publish <entity_id> <state> <friendly_name> <icon> <unit>
# No state_class on purpose: the unit follows the language option, and a changing unit under a
# state_class would trip Home Assistant's long-term statistics.
publish() {
    jq -n --arg state "$2" --arg name "$3" --arg icon "$4" --arg unit "$5" \
        '{state: $state, attributes: {friendly_name: $name, icon: $icon, unit_of_measurement: $unit}}' >"$BODY_FILE"
    printf 'header = "Authorization: Bearer %s"\nheader = "Content-Type: application/json"\n' "$SUPERVISOR_TOKEN" |
        curl -fsS -K - -X POST --data-binary "@$BODY_FILE" "$HA_API/states/$1" >/dev/null
}

is_count() { printf '%s' "$1" | grep -Eq '^[0-9]+$'; }

while true; do
    wait_seconds="$RETRY_INTERVAL"
    # last_update is null until the viewer has finished its first IMAP check; publishing before would report zeros.
    if summary="$(viewer_get /summary)" && printf '%s' "$summary" | jq -e '.last_update != null' >/dev/null &&
        reports="$(viewer_get /dmarc-reports)"; then
        total="$(printf '%s' "$summary" | jq -r '.dmarc.reports // 0')"
        spf="$(printf '%s' "$summary" | jq -r '.dmarc.spf_policy_results.pass // 0')"
        dkim="$(printf '%s' "$summary" | jq -r '.dmarc.dkim_policy_results.pass // 0')"
        flagged="$(printf '%s' "$reports" | jq -r '[.[] | select(.flagged)] | length')"
        if ! { is_count "$total" && is_count "$spf" && is_count "$dkim" && is_count "$flagged"; }; then
            echo "Unexpected response from the viewer (total='$total' spf='$spf' dkim='$dkim' flagged='$flagged'), not publishing." >&2
        elif publish sensor.dmarc_reports_total "$total" "$NAME_TOTAL" mdi:email-multiple "$UNIT_REPORTS" &&
            publish sensor.dmarc_spf_passed "$spf" "$NAME_SPF" mdi:shield-check "$UNIT_MAILS" &&
            publish sensor.dmarc_dkim_passed "$dkim" "$NAME_DKIM" mdi:key-variant "$UNIT_MAILS" &&
            publish sensor.dmarc_reports_flagged "$flagged" "$NAME_FLAGGED" mdi:shield-alert "$UNIT_REPORTS"; then
            wait_seconds="$PUSH_INTERVAL"
        else
            echo "Publishing sensors to Home Assistant failed, retrying." >&2
        fi
    else
        echo "Viewer not ready yet, retrying." >&2
    fi
    [ -n "${PUSH_ONCE:-}" ] && break
    sleep "$wait_seconds"
done
