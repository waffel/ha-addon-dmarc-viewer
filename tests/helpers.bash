# Shared helpers for the bats tests. The JSON fixtures follow the structure of the pinned upstream viewer
# (src/http/summary.rs and src/http/dmarc_reports.rs at the commit named in dmarc-viewer/Dockerfile).
# Re-check them when COMMIT changes.

load '/usr/lib/bats/bats-support/load'
load '/usr/lib/bats/bats-assert/load'
load '/usr/lib/bats/bats-file/load'

REPO=/repo
export REPO

READY='{"last_update":1,"dmarc":{"reports":1,"spf_policy_results":{"pass":2},"dkim_policy_results":{"pass":2,"fail":1}}}'
EMPTY='{"last_update":1,"dmarc":{"reports":0,"spf_policy_results":{},"dkim_policy_results":{}}}'
NOT_READY='{"last_update":null,"dmarc":{"reports":0,"spf_policy_results":{},"dkim_policy_results":{}}}'
NO_FLAGS='[{"id":"a","flagged":false}]'

# Starts the mock of the viewer and the Home Assistant API on 127.0.0.1:9000.
start_mock() { # summary_json reports_json
    echo "$1" >"$BATS_TEST_TMPDIR/summary.json"
    echo "$2" >"$BATS_TEST_TMPDIR/reports.json"
    # fd 3 is closed so bats does not wait for the background process
    python3 "$REPO/tests/mock_server.py" "$BATS_TEST_TMPDIR" 3>&- &
    MOCK_PID=$!
    local tries=0
    until curl -sf http://127.0.0.1:9000/summary >/dev/null; do
        tries=$((tries + 1))
        [ "$tries" -le 50 ] || { echo "mock server did not start" >&2; return 1; }
        sleep 0.2
    done
    rm -f "$BATS_TEST_TMPDIR/requests.log"
    : >"$BATS_TEST_TMPDIR/posts.jsonl"
}

stop_mock() {
    if [ -n "${MOCK_PID:-}" ]; then
        kill "$MOCK_PID" 2>/dev/null || true
        wait "$MOCK_PID" 2>/dev/null || true
    fi
}

# Runs push-states.sh once against the mock. Extra VAR=value arguments override the defaults.
run_push() {
    run env VIEWER_URL=http://127.0.0.1:9000 HA_API=http://127.0.0.1:9000 SUPERVISOR_TOKEN=test-token \
        PUSH_ONCE=1 "$@" sh "$REPO/dmarc-viewer/push-states.sh"
}

posts() { wc -l <"$BATS_TEST_TMPDIR/posts.jsonl" | tr -d ' '; }

# Prints a jq expression evaluated on the POST that was sent for an entity.
posted() { # entity_id jq_path
    jq -s -r --arg id "/states/$1" ".[] | select(.path == \$id) | $2" "$BATS_TEST_TMPDIR/posts.jsonl"
}
