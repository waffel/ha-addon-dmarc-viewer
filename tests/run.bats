#!/usr/bin/env bats

load helpers

setup() {
    mkdir "$BATS_TEST_TMPDIR/bin"
    # Stands in for the viewer and prints what run.sh passed to it through the environment.
    cat >"$BATS_TEST_TMPDIR/bin/dmarc-report-viewer" <<'FAKE'
#!/bin/sh
echo "$IMAP_HOST|$IMAP_USER|$IMAP_PASSWORD|$IMAP_FOLDER|$IMAP_CHECK_INTERVAL|$HTTP_SERVER_PASSWORD|$DMARC_LANGUAGE|$HTTP_SERVER_USER"
FAKE
    chmod +x "$BATS_TEST_TMPDIR/bin/dmarc-report-viewer"
}

run_start() { # options_json
    echo "$1" >"$BATS_TEST_TMPDIR/options.json"
    run env PATH="$BATS_TEST_TMPDIR/bin:$PATH" OPTIONS_FILE="$BATS_TEST_TMPDIR/options.json" PUSH_STATES=/bin/true \
        sh "$REPO/dmarc-viewer/run.sh"
}

@test "maps all options to environment variables" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":24,"web_ui_password":"w","language":"de"}'
    assert_success
    assert_output "h|u|p|F|86400|w|de|dmarc"
}

@test "defaults to an empty web UI password and english" {
    run_start '{"imap_host":"h","imap_user":"u","imap_password":"p","imap_folder":"F","check_interval_hours":2}'
    assert_success
    assert_output "h|u|p|F|7200||en|dmarc"
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
