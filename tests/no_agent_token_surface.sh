#!/usr/bin/env bash
#
# SPEC-omarchy red lines (backend, G2): the shipped plugin surface must never
# advertise or use a Geode agent / token interface. ci.yml already runs every
# tests/*.sh under `set -e`, so a non-zero exit here fails the tree.
#
# Scanned files (the shipped surface):
#   Model.js  BarWidget.qml  manifest.json  README.md
#
# Matched substrings (case-insensitive):
#   agent serve · GTOK · GEODE_TOKEN · tui --token · agent token
#
# `//` line comments are stripped before matching -- in the JS and the QML
# source alike. Model.js documents these very red lines in comments ("Red
# lines (SPEC-omarchy G0): no `--token`, no `GEODE_TOKEN` written by ..."),
# and documentation of the prohibition is not a usage of it. manifest.json has
# no comment syntax and README.md is shipped prose, so both are matched
# verbatim. Block comments are NOT stripped: no guarded source uses one, so a
# red-line string inside one fails loudly instead of passing silently.
#
# No `geode` subprocess, no socket, no Omarchy: awk + grep over four files.
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

# Comment-stripped view of one source file. One output line per input line, so
# reported line numbers stay the file's own.
strip_line_comments() {
    awk '{ sub(/\/\/.*/, ""); print }' "$1"
}

status=0
for f in "${files[@]}"; do
    case "$f" in
        *.js | *.qml) view=$(strip_line_comments "$f") ;;
        *) view=$(cat -- "$f") ;;
    esac

    for p in "${patterns[@]}"; do
        if found=$(printf '%s\n' "$view" | grep -inF -- "$p"); then
            echo "FAIL: $f carries the red-line string \"$p\" outside comments:" >&2
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
