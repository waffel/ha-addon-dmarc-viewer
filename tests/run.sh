#!/bin/sh
# Builds the test runner image and runs all bats tests in it. Nothing is installed on the host.
# Usage: sh tests/run.sh [extra bats arguments]
set -eu
cd "$(dirname "$0")/.."
docker build -q -t dmarc-addon-tests tests >/dev/null
docker run --rm -v "$PWD":/repo:ro dmarc-addon-tests "$@" /repo/tests
