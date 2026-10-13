#!/bin/sh
# Reads the viewer's summary and publishes it as Home Assistant sensors (sensor.dmarc_*),
# using the add-on's Supervisor token. Runs next to the viewer inside the same container.
# Environment (all optional, defaults fit the add-on): VIEWER_URL, HA_API, PUSH_INTERVAL (seconds),
# RETRY_INTERVAL (seconds), PUSH_ONCE (set to run a single round), HTTP_SERVER_USER/HTTP_SERVER_PASSWORD.
set -u

VIEWER_URL="${VIEWER_URL:-http://127.0.0.1:8080}"
HA_API="${HA_API:-http://supervisor/core/api}"
PUSH_INTERVAL="${PUSH_INTERVAL:-600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-30}"

viewer_get() {
    if [ -n "${HTTP_SERVER_PASSWORD:-}" ]; then
        printf 'user = "%s:%s"\n' "${HTTP_SERVER_USER:-dmarc}" "$HTTP_SERVER_PASSWORD" |
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
publish() {
    jq -n --arg state "$2" --arg name "$3" --arg icon "$4" --arg unit "$5" \
        '{state: $state, attributes: {friendly_name: $name, icon: $icon, unit_of_measurement: $unit, state_class: "measurement"}}' |
        curl -fsS -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN:?SUPERVISOR_TOKEN is not set}" \
            -H "Content-Type: application/json" -d @- "$HA_API/states/$1" >/dev/null
}

while true; do
    # last_update is null until the viewer has finished its first IMAP check; publishing before would report zeros.
    if summary="$(viewer_get /summary)" && echo "$summary" | jq -e ".last_update != null" >/dev/null && reports="$(viewer_get /dmarc-reports)"; then
        total="$(echo "$summary" | jq -r '.dmarc.reports // 0')"
        spf="$(echo "$summary" | jq -r '.dmarc.spf_policy_results.pass // 0')"
        dkim="$(echo "$summary" | jq -r '.dmarc.dkim_policy_results.pass // 0')"
        flagged="$(echo "$reports" | jq -r '[.[] | select(.flagged)] | length')"
        if publish sensor.dmarc_reports_total "$total" "$NAME_TOTAL" mdi:email-multiple "$UNIT_REPORTS" &&
            publish sensor.dmarc_spf_passed "$spf" "$NAME_SPF" mdi:shield-check "$UNIT_MAILS" &&
            publish sensor.dmarc_dkim_passed "$dkim" "$NAME_DKIM" mdi:key-variant "$UNIT_MAILS" &&
            publish sensor.dmarc_reports_flagged "$flagged" "$NAME_FLAGGED" mdi:shield-alert "$UNIT_REPORTS"; then
            wait_seconds="$PUSH_INTERVAL"
        else
            echo "Publishing sensors to Home Assistant failed, retrying." >&2
            wait_seconds="$RETRY_INTERVAL"
        fi
    else
        echo "Viewer not ready yet, retrying." >&2
        wait_seconds="$RETRY_INTERVAL"
    fi
    [ -n "${PUSH_ONCE:-}" ] && break
    sleep "$wait_seconds"
done
