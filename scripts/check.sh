#!/usr/bin/env sh
# Formatting, lint and offline tests. Run before committing.
set -e
cd "$(dirname "$0")/.."
stylua --check src tests
selene src
lune run tests/run.luau
