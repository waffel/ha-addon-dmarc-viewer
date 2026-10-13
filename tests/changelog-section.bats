#!/usr/bin/env bats

load helpers

setup() {
    cat >"$BATS_TEST_TMPDIR/CHANGELOG.md" <<'LOG'
# Changelog

## [Unreleased]
- not yet

## [1.2.0] - 2026-01-01
### Added
- feature a

## [1.1.0] - 2025-12-01
- old
LOG
}

@test "extracts only the requested section" {
    run sh "$REPO/scripts/changelog-section.sh" 1.2.0 "$BATS_TEST_TMPDIR/CHANGELOG.md"
    assert_success
    assert_line --index 0 "### Added"
    assert_line --index 1 "- feature a"
    refute_output --partial "old"
    refute_output --partial "not yet"
}

@test "fails for an unknown version" {
    run sh "$REPO/scripts/changelog-section.sh" 9.9.9 "$BATS_TEST_TMPDIR/CHANGELOG.md"
    assert_failure
    assert_output --partial "No changelog section"
}

@test "fails for an empty section" {
    printf '## [2.0.0] - 2026-02-01\n\n## [1.2.0] - 2026-01-01\n- a\n' >"$BATS_TEST_TMPDIR/CHANGELOG.md"
    run sh "$REPO/scripts/changelog-section.sh" 2.0.0 "$BATS_TEST_TMPDIR/CHANGELOG.md"
    assert_failure
}
