#!/usr/bin/env bats

load helpers

teardown() { stop_mock; }

@test "publishes the four sensors with the parsed values" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_success
    assert_equal "$(posts)" 4
    assert_equal "$(posted sensor.dmarc_reports_total .body.state)" 1
    assert_equal "$(posted sensor.dmarc_spf_passed .body.state)" 2
    assert_equal "$(posted sensor.dmarc_dkim_passed .body.state)" 2
    assert_equal "$(posted sensor.dmarc_reports_flagged .body.state)" 0
}

@test "asks the viewer for the summary and the reports" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_file_contains "$BATS_TEST_TMPDIR/requests.log" '^/summary$'
    assert_file_contains "$BATS_TEST_TMPDIR/requests.log" '^/dmarc-reports$'
}

@test "uses english names by default" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_equal "$(posted sensor.dmarc_reports_total .body.attributes.friendly_name)" "DMARC reports received"
    assert_equal "$(posted sensor.dmarc_spf_passed .body.attributes.friendly_name)" "DMARC mails passing SPF"
    assert_equal "$(posted sensor.dmarc_dkim_passed .body.attributes.friendly_name)" "DMARC mails passing DKIM"
    assert_equal "$(posted sensor.dmarc_reports_flagged .body.attributes.friendly_name)" "DMARC reports flagged"
}

@test "uses german names for language de" {
    start_mock "$READY" "$NO_FLAGS"
    run_push DMARC_LANGUAGE=de
    assert_equal "$(posted sensor.dmarc_reports_total .body.attributes.friendly_name)" "DMARC-Berichte erhalten"
    assert_equal "$(posted sensor.dmarc_spf_passed .body.attributes.friendly_name)" "DMARC-Mails mit SPF bestanden"
    assert_equal "$(posted sensor.dmarc_dkim_passed .body.attributes.friendly_name)" "DMARC-Mails mit DKIM bestanden"
    assert_equal "$(posted sensor.dmarc_reports_flagged .body.attributes.friendly_name)" "DMARC-Berichte auffällig"
}

@test "all sensors share one blank unit so Home Assistant draws them in one history chart" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    run jq -s -e '[.[].body.attributes.unit_of_measurement] | unique == [" "]' "$BATS_TEST_TMPDIR/posts.jsonl"
    assert_success
}

@test "sets no state_class" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_equal "$(posted sensor.dmarc_spf_passed '.body.attributes | has("state_class")')" false
}

@test "sends the supervisor token as bearer token" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_equal "$(posted sensor.dmarc_reports_total .auth)" "Bearer test-token"
}

@test "ignores the DKIM fail count" {
    start_mock "$READY" "$NO_FLAGS"
    run_push
    assert_equal "$(posted sensor.dmarc_dkim_passed .body.state)" 2
}

@test "counts only flagged reports" {
    start_mock "$READY" '[{"flagged":true},{"flagged":false},{"flagged":true}]'
    run_push
    assert_equal "$(posted sensor.dmarc_reports_flagged .body.state)" 2
}

@test "counts a missing pass key and an empty report list as zero" {
    start_mock "$EMPTY" '[]'
    run_push
    assert_equal "$(posted sensor.dmarc_spf_passed .body.state)" 0
    assert_equal "$(posted sensor.dmarc_reports_flagged .body.state)" 0
}

@test "publishes nothing before the first mailbox check" {
    start_mock "$NOT_READY" '[]'
    run_push
    assert_file_contains "$BATS_TEST_TMPDIR/requests.log" '^/summary$'
    assert_equal "$(posts)" 0
    assert_output --partial "not ready"
}

@test "publishes nothing for an unexpected reports response" {
    start_mock "$READY" '{"unexpected":"object"}'
    run_push
    assert_equal "$(posts)" 0
    assert_output --partial "Unexpected response"
}

@test "authenticates with a web UI password that contains quotes and backslashes" {
    local password='p"a\ss word'
    start_mock "$READY" "$NO_FLAGS"
    printf 'Basic %s' "$(printf 'dmarc:%s' "$password" | base64)" >"$BATS_TEST_TMPDIR/auth.expected"
    run_push HTTP_SERVER_PASSWORD="$password"
    assert_equal "$(posts)" 4
}

@test "does not publish when the web UI password is wrong" {
    start_mock "$READY" "$NO_FLAGS"
    printf 'Basic %s' "$(printf 'dmarc:right' | base64)" >"$BATS_TEST_TMPDIR/auth.expected"
    run_push HTTP_SERVER_PASSWORD=wrong
    assert_equal "$(posts)" 0
    assert_output --partial "not ready"
}

@test "never puts the supervisor token or the web UI password on a command line" {
    mkdir "$BATS_TEST_TMPDIR/spy"
    printf '#!/bin/sh\necho "$@" >>"%s/argv.log"\nexec /usr/bin/curl "$@"\n' "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/spy/curl"
    chmod +x "$BATS_TEST_TMPDIR/spy/curl"
    start_mock "$READY" "$NO_FLAGS"
    run_push PATH="$BATS_TEST_TMPDIR/spy:$PATH" SUPERVISOR_TOKEN=sentinel-token-123 HTTP_SERVER_PASSWORD=sentinel-password-456
    assert_equal "$(posts)" 4
    assert_file_exists "$BATS_TEST_TMPDIR/argv.log"
    assert_file_not_contains "$BATS_TEST_TMPDIR/argv.log" 'sentinel-token-123'
    assert_file_not_contains "$BATS_TEST_TMPDIR/argv.log" 'sentinel-password-456'
}

@test "exits with a clear message without a supervisor token" {
    run_push SUPERVISOR_TOKEN=
    assert_failure
    assert_output --partial "SUPERVISOR_TOKEN"
}
