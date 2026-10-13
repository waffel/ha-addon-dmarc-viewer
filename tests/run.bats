#!/usr/bin/env bats

load helpers

setup() {
    # The viewer stand-in lives outside the per-test directory: bats creates that one readable by root only.
    FAKEBIN="$(mktemp -d /tmp/fakebin.XXXXXX)"
    chmod 755 "$FAKEBIN"
    # Stands in for the viewer. Line 1: what run.sh passed through the environment, line 2: how it was started.
    cat >"$FAKEBIN/dmarc-report-viewer" <<'FAKE'
#!/bin/sh
echo "$IMAP_HOST|$IMAP_USER|$IMAP_PASSWORD|$IMAP_FOLDER|$IMAP_CHECK_INTERVAL|$HTTP_SERVER_PASSWORD|$DMARC_LANGUAGE|$HTTP_SERVER_USER"
echo "uid=$(id -u) token=${SUPERVISOR_TOKEN:-unset} legacy=${HASSIO_TOKEN:-unset}"
FAKE
    chmod 755 "$FAKEBIN/dmarc-report-viewer"
}

teardown() { rm -rf "$FAKEBIN"; }

run_start() { # options_json [VAR=value ...]
    echo "$1" >"$BATS_TEST_TMPDIR/options.json"
    shift
    run env PATH="$FAKEBIN:$PATH" OPTIONS_FILE="$BATS_TEST_TMPDIR/options.json" PUSH_STATES=/bin/true \
        "$@" sh "$REPO/dmarc-viewer/run.sh"
}

@test "maps all options to environment variables" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24,"web_ui_password":"w","language":"de"}'
    assert_success
    assert_line --index 0 "h|u|p|F|86400|w|de|dmarc"
}

@test "defaults to an empty web UI password and english" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":2}'
    assert_success
    assert_line --index 0 "h|u|p|F|7200||en|dmarc"
}

# Why: a compromised viewer must not get root in the container.
@test "runs the viewer as an unprivileged user" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24}'
    assert_success
    assert_line --regexp '^uid=[1-9][0-9]* '
}

# Why: the supervisor token can control Home Assistant; only the publisher needs it.
@test "keeps the supervisor token away from the viewer" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24}' SUPERVISOR_TOKEN=secret-token
    assert_success
    assert_line --partial "token=unset"
    refute_output --partial "secret-token"
}

# Why: older supervisors expose the same token under a second name.
@test "keeps the legacy supervisor token name away from the viewer" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24}' HASSIO_TOKEN=legacy-secret
    assert_success
    assert_line --partial "legacy=unset"
    refute_output --partial "legacy-secret"
}

@test "refuses to start without imap_host" {
    run_start '{"imap_host":"","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24}'
    assert_failure
    assert_output --partial "imap_host"
}

@test "refuses to start when imap_host is missing from the options" {
    run_start '{"imap_user":"u","imap_password":"p","imap_folder":"F"}'
    assert_failure
    assert_output --partial "imap_host"
}

@test "refuses to start without imap_password" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"","imap_folder":"F"}'
    assert_failure
    assert_output --partial "imap_password"
}
