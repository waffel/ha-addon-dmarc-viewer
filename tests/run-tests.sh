#!/bin/sh
# Tests for run.sh, push-states.sh and scripts/changelog-section.sh. They run inside a throw-away Alpine container:
#   docker run --rm -v "$PWD":/repo:ro alpine:3.21 sh /repo/tests/run-tests.sh
#
# The JSON fixtures follow the structure of the pinned upstream viewer (src/http/summary.rs and
# src/http/dmarc_reports.rs at the commit named in dmarc-viewer/Dockerfile). Re-check them when COMMIT changes.
set -u

apk add -q --no-cache python3 curl jq >/dev/null
REPO=/repo
WORK="$(mktemp -d)"
failed=0

pass() { echo "ok   - $1"; }
fail() { echo "FAIL - $1"; failed=1; }
assert_eq() { # description actual expected
    if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi
}
assert_contains() { # description file text
    if grep -qF -- "$3" "$2"; then pass "$1"; else fail "$1 (no '$3' in $2)"; fi
}
assert_not_contains() { # description file text
    if grep -qF -- "$3" "$2"; then fail "$1 ('$3' found in $2)"; else pass "$1"; fi
}

start_mock() { # summary_json reports_json
    echo "$1" >"$WORK/summary.json"
    echo "$2" >"$WORK/reports.json"
    rm -f "$WORK/posts.jsonl" "$WORK/requests.log" "$WORK/auth.expected" "$WORK/argv.log"
    python3 "$REPO/tests/mock_server.py" "$WORK" &
    MOCK_PID=$!
    tries=0
    until curl -sf http://127.0.0.1:9000/summary >/dev/null; do
        tries=$((tries + 1))
        if [ "$tries" -gt 50 ]; then fail "mock server did not start"; exit 1; fi
        sleep 0.2
    done
    rm -f "$WORK/requests.log"
    : >"$WORK/posts.jsonl"
}
stop_mock() { kill "$MOCK_PID" && wait "$MOCK_PID" 2>/dev/null; }

run_push() { # extra VAR=value arguments
    env VIEWER_URL=http://127.0.0.1:9000 HA_API=http://127.0.0.1:9000 SUPERVISOR_TOKEN=test-token \
        PUSH_ONCE=1 "$@" sh "$REPO/dmarc-viewer/push-states.sh" 2>"$WORK/stderr"
}
posts() { wc -l <"$WORK/posts.jsonl" | tr -d ' '; }
posted() { # entity_id jq_path
    jq -s -r --arg id "/states/$1" ".[] | select(.path == \$id) | $2" "$WORK/posts.jsonl"
}

READY='{"last_update":1,"dmarc":{"reports":1,"spf_policy_results":{"pass":2},"dkim_policy_results":{"pass":2,"fail":1}}}'
EMPTY='{"last_update":1,"dmarc":{"reports":0,"spf_policy_results":{},"dkim_policy_results":{}}}'
NOT_READY='{"last_update":null,"dmarc":{"reports":0,"spf_policy_results":{},"dkim_policy_results":{}}}'
NO_FLAGS='[{"id":"a","flagged":false}]'

echo "# push-states.sh"

start_mock "$READY" "$NO_FLAGS"
run_push
assert_eq "publishes four sensors" "$(posts)" "4"
assert_eq "reports received" "$(posted sensor.dmarc_reports_total .body.state)" "1"
assert_eq "mails passing SPF" "$(posted sensor.dmarc_spf_passed .body.state)" "2"
assert_eq "mails passing DKIM (fail count is ignored)" "$(posted sensor.dmarc_dkim_passed .body.state)" "2"
assert_eq "flagged reports without flags" "$(posted sensor.dmarc_reports_flagged .body.state)" "0"
assert_eq "english name" "$(posted sensor.dmarc_spf_passed .body.attributes.friendly_name)" "DMARC mails passing SPF"
assert_eq "english unit of mails" "$(posted sensor.dmarc_spf_passed .body.attributes.unit_of_measurement)" "mails"
assert_eq "english unit of reports" "$(posted sensor.dmarc_reports_total .body.attributes.unit_of_measurement)" "reports"
assert_eq "no state_class (unit follows the language)" "$(posted sensor.dmarc_spf_passed '.body.attributes | has("state_class")')" "false"
assert_eq "supervisor token is sent" "$(posted sensor.dmarc_reports_total .auth)" "Bearer test-token"
assert_contains "asks the viewer for the summary" "$WORK/requests.log" "/summary"
assert_contains "asks the viewer for the reports" "$WORK/requests.log" "/dmarc-reports"
stop_mock

start_mock "$READY" "$NO_FLAGS"
run_push DMARC_LANGUAGE=de
assert_eq "german name" "$(posted sensor.dmarc_spf_passed .body.attributes.friendly_name)" "DMARC-Mails mit SPF bestanden"
assert_eq "german unit of reports" "$(posted sensor.dmarc_reports_total .body.attributes.unit_of_measurement)" "Berichte"
assert_eq "german unit of mails" "$(posted sensor.dmarc_dkim_passed .body.attributes.unit_of_measurement)" "Mails"
stop_mock

start_mock "$READY" '[{"flagged":true},{"flagged":false},{"flagged":true}]'
run_push
assert_eq "counts only flagged reports" "$(posted sensor.dmarc_reports_flagged .body.state)" "2"
stop_mock

start_mock "$EMPTY" '[]'
run_push
assert_eq "missing pass key counts as zero" "$(posted sensor.dmarc_spf_passed .body.state)" "0"
assert_eq "empty report list counts as zero" "$(posted sensor.dmarc_reports_flagged .body.state)" "0"
stop_mock

start_mock "$NOT_READY" '[]'
run_push
assert_contains "the mock was reached before giving up" "$WORK/requests.log" "/summary"
assert_eq "publishes nothing before the first mailbox check" "$(posts)" "0"
assert_contains "reports that the viewer is not ready" "$WORK/stderr" "not ready"
stop_mock

start_mock "$READY" '{"unexpected":"object"}'
run_push
assert_eq "publishes nothing for an unexpected reports response" "$(posts)" "0"
assert_contains "reports the unexpected response" "$WORK/stderr" "Unexpected response"
stop_mock

PASSWORD='p"a\ss word'
start_mock "$READY" "$NO_FLAGS"
printf 'Basic %s' "$(printf 'dmarc:%s' "$PASSWORD" | base64)" >"$WORK/auth.expected"
run_push HTTP_SERVER_PASSWORD="$PASSWORD"
assert_eq "basic auth with quotes and backslashes in the password" "$(posts)" "4"
run_push HTTP_SERVER_PASSWORD="wrong"
assert_contains "wrong password is not published as success" "$WORK/stderr" "not ready"
stop_mock

mkdir -p "$WORK/curl-spy"
cat >"$WORK/curl-spy/curl" <<SPY
#!/bin/sh
echo "\$@" >>"$WORK/argv.log"
exec /usr/bin/curl "\$@"
SPY
chmod +x "$WORK/curl-spy/curl"
start_mock "$READY" "$NO_FLAGS"
run_push PATH="$WORK/curl-spy:$PATH" SUPERVISOR_TOKEN=sentinel-token-123 HTTP_SERVER_PASSWORD=sentinel-password-456
assert_eq "spy saw the curl calls" "$([ -s "$WORK/argv.log" ] && echo yes || echo no)" "yes"
assert_eq "all sensors were still published" "$(posts)" "4"
assert_not_contains "supervisor token is never a command line argument" "$WORK/argv.log" "sentinel-token-123"
assert_not_contains "web UI password is never a command line argument" "$WORK/argv.log" "sentinel-password-456"
stop_mock

if run_push SUPERVISOR_TOKEN= 2>/dev/null; then fail "exits without a supervisor token"; else pass "exits without a supervisor token"; fi
assert_contains "names the missing supervisor token" "$WORK/stderr" "SUPERVISOR_TOKEN"

echo "# run.sh"

mkdir -p "$WORK/bin"
cat >"$WORK/bin/dmarc-report-viewer" <<'FAKE'
#!/bin/sh
echo "$IMAP_HOST|$IMAP_USER|$IMAP_PASSWORD|$IMAP_FOLDER|$IMAP_CHECK_INTERVAL|$HTTP_SERVER_PASSWORD|$DMARC_LANGUAGE|$HTTP_SERVER_USER"
FAKE
chmod +x "$WORK/bin/dmarc-report-viewer"

run_start() { # options_json
    echo "$1" >"$WORK/options.json"
    env PATH="$WORK/bin:$PATH" OPTIONS_FILE="$WORK/options.json" PUSH_STATES=/bin/true \
        sh "$REPO/dmarc-viewer/run.sh" 2>"$WORK/stderr"
}

out="$(run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24,"web_ui_password":"w","language":"de"}')"
assert_eq "maps all options to environment variables" "$out" "h|u|p|F|86400|w|de|dmarc"

out="$(run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":2}')"
assert_eq "defaults: empty web password, english" "$out" "h|u|p|F|7200||en|dmarc"

if run_start '{"imap_host":"","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24}' >/dev/null; then
    fail "refuses to start without imap_host"
else
    pass "refuses to start without imap_host"
fi
assert_contains "names the missing option" "$WORK/stderr" "imap_host"

if run_start '{"imap_user":"u","imap_password":"p","imap_folder":"F"}' >/dev/null; then
    fail "refuses to start when imap_host is missing from the options"
else
    pass "refuses to start when imap_host is missing from the options"
fi

echo "# changelog-section.sh"

cat >"$WORK/CHANGELOG.md" <<'LOG'
# Changelog

## [Unreleased]
- not yet

## [1.2.0] - 2026-01-01
### Added
- feature a

## [1.1.0] - 2025-12-01
- old
LOG
section="$(sh "$REPO/scripts/changelog-section.sh" 1.2.0 "$WORK/CHANGELOG.md")"
assert_eq "extracts only the requested section" "$(printf '%s' "$section" | tr -d '\n')" "### Added- feature a"
if sh "$REPO/scripts/changelog-section.sh" 9.9.9 "$WORK/CHANGELOG.md" >/dev/null 2>&1; then
    fail "fails for an unknown version"
else
    pass "fails for an unknown version"
fi

echo "# configuration, docs and translations agree"

keys() { # section_name_before section_name_after file
    awk -v from="$1" -v to="$2" '$0 == from ":" {s=1; next} $0 == to ":" {s=0} s && /^  [a-z_]+:/ {sub(/:.*/, ""); print $1}' "$3"
}
keys options schema "$REPO/dmarc-viewer/config.yaml" >"$WORK/options.list"
keys schema __end__ "$REPO/dmarc-viewer/config.yaml" >"$WORK/schema.list"
if [ -s "$WORK/options.list" ]; then pass "found the options in config.yaml"; else fail "found the options in config.yaml"; fi
assert_eq "options and schema have the same keys" "$(sort "$WORK/options.list" | tr '\n' ' ')" "$(sort "$WORK/schema.list" | tr '\n' ' ')"
while read -r option; do
    if grep -q "^| \`$option\` |" "$REPO/dmarc-viewer/DOCS.md"; then pass "$option is in the DOCS.md table"; else fail "$option is not in the DOCS.md table"; fi
    for file in translations/en.yaml translations/de.yaml; do
        if grep -q "^  $option:" "$REPO/dmarc-viewer/$file"; then pass "$option is in $file"; else fail "$option is missing in $file"; fi
    done
done <"$WORK/options.list"
if cmp -s "$REPO/CHANGELOG.md" "$REPO/dmarc-viewer/CHANGELOG.md"; then
    pass "both changelog copies are identical"
else
    fail "dmarc-viewer/CHANGELOG.md differs from CHANGELOG.md"
fi

[ "$failed" -eq 0 ] && echo "ALL TESTS PASSED" || echo "TESTS FAILED"
exit "$failed"
