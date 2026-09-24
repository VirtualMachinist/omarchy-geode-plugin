#!/usr/bin/env bash
#
# SPEC-omarchy red lines (backend, G2c): the shipped plugin surface must never
# advertise or use a Geode agent / token interface. ci.yml already runs every
# tests/*.sh under `set -e`, so a non-zero exit here fails the tree.
#
# Scanned files (the shipped surface):
#   Model.js  BarWidget.qml  manifest.json  README.md
#
# Matched substrings (case-insensitive):
#   agent serve · GTOK · GEODE_TOKEN · tui --token · agent token
#
# The four files are scanned as RAW TEXT: no comment stripping, no escaping, no
# exclusions. A red-line string is a red line wherever it appears -- source,
# JSON, prose, or a `//` comment. Comment cleanup (PR #5) removed these
# substrings from Model.js's comments, which is what keeps the clean tree
# green; a comment that reintroduces `GEODE_TOKEN` fails it again.
#
# No `geode` subprocess, no socket, no Omarchy: grep over four files.
#
# Exit 0 when the tree is clean, 1 on any hit or missing guarded file.

set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

files=(Model.js BarWidget.qml manifest.json README.md)
patterns=("agent serve" "GTOK" "GEODE_TOKEN" "tui --token" "agent token")

# A missing guarded file would silently leave the guard checking nothing, so a
# rename or delete must fail the tree rather than pass it.
for f in "${files[@]}"; do
    if [ ! -f "$f" ]; then
        echo "FAIL: guarded file missing from the plugin surface: $f" >&2
        exit 1
    fi
done

status=0
for f in "${files[@]}"; do
    for p in "${patterns[@]}"; do
        if found=$(grep -inF -- "$p" "$f"); then
            echo "FAIL: $f carries the red-line string \"$p\":" >&2
            printf '%s\n' "$found" | awk '{ print "  " $0 }' >&2
            status=1
        fi
    done
done

if [ "$status" -ne 0 ]; then
    echo "FAIL: the red-line strings above must not ship (SPEC-omarchy)" >&2
    exit 1
fi

echo "ok: no agent/token surface in ${files[*]}"
