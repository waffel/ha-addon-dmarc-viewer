#!/usr/bin/env bats
# The add-on configuration, its documentation and its translations must describe the same options.

load helpers

CONFIG="$REPO/dmarc-viewer/config.yaml"

# Prints the keys (two-space indented) of a top-level section of a YAML file.
keys() { # section file
    awk -v section="$1" '$0 == section ":" {s=1; next} /^[a-z_]+:/ {s=0} s && /^  [a-z_]+:/ {sub(/:.*/, ""); print $1}' "$2"
}

@test "config.yaml has options" {
    [ -n "$(keys options "$CONFIG")" ]
}

@test "options and schema have the same keys" {
    assert_equal "$(keys options "$CONFIG" | sort | tr '\n' ' ')" "$(keys schema "$CONFIG" | sort | tr '\n' ' ')"
}

@test "every option is in the DOCS.md table" {
    for option in $(keys options "$CONFIG"); do
        assert_file_contains "$REPO/dmarc-viewer/DOCS.md" "^\| \`$option\` \|"
    done
}

@test "every option is in the english and german translation" {
    for option in $(keys options "$CONFIG"); do
        assert_file_contains "$REPO/dmarc-viewer/translations/en.yaml" "^  $option:"
        assert_file_contains "$REPO/dmarc-viewer/translations/de.yaml" "^  $option:"
    done
}

@test "the add-on version is a semantic version" {
    run sed -n 's/^version: "\(.*\)"$/\1/p' "$CONFIG"
    assert_output --regexp '^[0-9]+\.[0-9]+\.[0-9]+(-dev)?$'
}

@test "both changelog copies are identical" {
    run cmp "$REPO/CHANGELOG.md" "$REPO/dmarc-viewer/CHANGELOG.md"
    assert_success
}

@test "the supervisor watchdog checks the viewer's health route" {
    assert_file_contains "$CONFIG" '^watchdog: "http://\[HOST\]:\[PORT:8080\]/health"$'
}

@test "the image installs su-exec for dropping privileges" {
    assert_file_contains "$REPO/dmarc-viewer/Dockerfile" 'apk add.*su-exec'
}
