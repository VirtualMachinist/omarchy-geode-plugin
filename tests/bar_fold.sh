#!/usr/bin/env bash
#
# SPEC-omarchy bar fold (backend, G1d): lock the Quickshell 0.3.0 fold that
# PR #7 landed, so a later edit cannot quietly put it back the old way.
# ci.yml already runs every tests/*.sh under `set -e`.
#
# Scanned file: BarWidget.qml, as RAW TEXT (no comment stripping).
#
# Fails when any of these is true:
#   1. the file contains `onFailedToStart`. Quickshell 0.3.0's Process has no
#      such signal, so a missing `geode` binary would never be reported.
#   2. the file contains `geodeRun.exitCode`. Process has no `exitCode`
#      property: the read is `undefined` and the status folds wrong. A comment
#      that merely says `exitCode` is allowed -- the read is what fails.
#   3. the `onExited` handler does not call `refresh` with `collector.text`,
#      in the same call. The handler is the single fold point; stdout must come
#      from the StdioCollector, not from a property that does not exist.
#   4. the file does not call `Model.statusFromRun(127, "", "")`, the
#      missing-binary shape for a run that never emits `exited`.
#
# Checks 3 and 4 are text checks, not parsers: 3 is scoped to the `onExited`
# binding (a mention elsewhere does not satisfy it) and is whitespace and
# line-break tolerant; 4 asks only that the call text is present.
#
# No geode subprocess, no socket, no Omarchy, no QML runtime: grep + awk.
#
# Exit 0 when the fold is locked, 1 on any violation or a missing BarWidget.qml.

set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

qml=BarWidget.qml
if [ ! -f "$qml" ]; then
    echo "FAIL: $qml missing from the plugin surface" >&2
    exit 1
fi

status=0

report() {
    echo "FAIL: $1" >&2
    printf '%s\n' "$2" | awk 'NF { print "  " $0 }' >&2
}

# 1. no onFailedToStart
if found=$(grep -nF -- "onFailedToStart" "$qml"); then
    report "$qml uses onFailedToStart, which Process does not emit on Quickshell 0.3.0:" "$found"
    status=1
fi

# 2. no geodeRun.exitCode read (a bare `exitCode` in a comment is fine)
if found=$(grep -nF -- "geodeRun.exitCode" "$qml"); then
    report "$qml reads geodeRun.exitCode, which Process does not expose:" "$found"
    status=1
fi

# 3. the onExited binding must fold collector.text through refresh.
#    Scoped to that binding so a mention elsewhere in the file cannot satisfy
#    it, and flattened so a line break inside the call does not break it.
handler=$(
    awk '
        /onExited[[:space:]]*:/ { inblk = 1; opened = 0; depth = 0 }
        inblk {
            print
            opens = gsub(/\{/, "{")
            closes = gsub(/\}/, "}")
            depth += opens - closes
            if (opens > 0) opened = 1
            if (opened && depth <= 0) exit
            if (!opened) exit
        }
    ' "$qml" | tr '\n' ' '
)
if ! printf '%s' "$handler" | grep -Eq 'refresh[[:space:]]*\([^)]*collector[[:space:]]*\.[[:space:]]*text'; then
    report "$qml onExited does not call refresh with collector.text:" "${handler:-<no onExited binding found>}"
    status=1
fi

# 4. the missing-binary shape must still be called.
flat=$(tr '\n' ' ' <"$qml")
if ! printf '%s' "$flat" | grep -qF -- 'Model.statusFromRun(127, "", "")'; then
    report "$qml does not call Model.statusFromRun(127, \"\", \"\") for the missing-binary case:" ""
    status=1
fi

if [ "$status" -ne 0 ]; then
    echo "FAIL: the BarWidget fold is not locked (SPEC-omarchy G1d)" >&2
    exit 1
fi

echo "ok: BarWidget.qml keeps the G1d fold (no onFailedToStart, no geodeRun.exitCode, onExited folds collector.text, missing-binary call present)"
