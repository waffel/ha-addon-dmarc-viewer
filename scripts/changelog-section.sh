#!/bin/sh
# Prints the body of the CHANGELOG.md section "## [<version>]" (without the heading).
# Fails if the section does not exist or is empty.
# Usage: sh scripts/changelog-section.sh <version> [changelog-file]
set -eu
version="${1:?Usage: changelog-section.sh <version> [changelog-file]}"
file="${2:-CHANGELOG.md}"
notes="$(awk -v v="$version" '
    /^## \[/ { in_section = (index($0, "## [" v "]") == 1); next }
    in_section { print }
' "$file")"
if [ -z "$(printf '%s' "$notes" | tr -d '[:space:]')" ]; then
    echo "No changelog section for version $version in $file" >&2
    exit 1
fi
printf '%s\n' "$notes"
