#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_dir="$(mktemp -d)"
trap 'rm -rf "$test_dir"' EXIT
swiftc -swift-version 5 App/Core/*.swift Tests/CoreTests.swift -o "$test_dir/core-tests"
"$test_dir/core-tests"
