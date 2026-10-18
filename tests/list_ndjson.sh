#!/usr/bin/env bash
#
# Issue #12: Model.js statusFromRun must read geode 1.2.1 `list --output json`
# (one geode.event.v1 document per line) and still read one JSON document
# from an older binary. ci.yml already runs every tests/*.sh under `set -e`.
#
# Loads Model.js in node (the `.pragma library` line is dropped; it is QML,
# not JavaScript) and checks the fixtures below. No geode subprocess, no QML
# runtime.
#
# Exit 0 when every fixture folds as expected, 1 otherwise or without node.

set -euo pipefail

root=$(cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

if ! command -v node >/dev/null 2>&1; then
    echo "FAIL: node is required to load Model.js" >&2
    exit 1
fi

node - Model.js <<'JS'
const fs = require("fs");
const vm = require("vm");

const src = fs.readFileSync(process.argv[2], "utf8").replace(/^\.pragma library.*$/m, "");
const M = {};
vm.runInNewContext(src + "\nthis.statusFromRun = statusFromRun;", M);

let failed = 0;
function check(name, got, want) {
    const g = JSON.stringify({ ok: got.ok, entries: got.entries });
    const w = JSON.stringify(want);
    if (g !== w) {
        console.error(`FAIL: ${name}: got ${g}, want ${w}`);
        failed = 1;
    } else {
        console.log(`ok: ${name}`);
    }
}

// The two-line sample from issue #12, as geode 1.2.1 prints it.
const ndjson =
    '{"content_root":"650239ad0d1172ad50cc49fc302f0828f59e280dd8ad2468192def7677206ff6","epoch":1,"key_id":"5d75d47c2269b65dc7159205ce7e5035","ok":true,"path":"demo-key.txt","plain_bytes":18,"schema":"geode.event.v1","vault_id":"7a67f6b5b774d2a8e78f1de88f95b306","verb":"list"}\n' +
    '{"epoch":1,"files":1,"key_id":"5d75d47c2269b65dc7159205ce7e5035","ok":true,"plain_bytes":18,"schema":"geode.event.v1","vault_id":"7a67f6b5b774d2a8e78f1de88f95b306","verb":"list"}\n';

check("1.2.1 NDJSON entry + summary", M.statusFromRun(0, ndjson, ""), { ok: true, entries: ["demo-key.txt"] });
check("NDJSON without trailing newline", M.statusFromRun(0, ndjson.trimEnd(), ""), { ok: true, entries: ["demo-key.txt"] });
check("NDJSON with CRLF", M.statusFromRun(0, ndjson.replace(/\n/g, "\r\n"), ""), { ok: true, entries: ["demo-key.txt"] });
check("one document with entries", M.statusFromRun(0, '{"entries":["a.txt"],"ok":true}', ""), { ok: true, entries: ["a.txt"] });
check("one pretty-printed document", M.statusFromRun(0, '{\n  "entries": ["a.txt"],\n  "ok": true\n}\n', ""), { ok: true, entries: ["a.txt"] });
check(
    "empty vault: summary files 0",
    M.statusFromRun(0, '{"epoch":1,"files":0,"ok":true,"plain_bytes":0,"schema":"geode.event.v1","verb":"list"}\n', ""),
    { ok: true, entries: [] }
);

// The files count never lands in entries.
const counted = M.statusFromRun(0, '{"files":3,"ok":true}\n', "");
check("files count is not entries", counted, { ok: true, entries: [] });

// Failure shapes.
check("non-zero exit", M.statusFromRun(1, ndjson, "geode list: boom"), { ok: false, entries: [] });
const missing = M.statusFromRun(127, "", "");
check("exit 127", missing, { ok: false, entries: [] });
if (!/install it with: cargo install geode-cli --version 1\.2\.1/.test(missing.reason)) {
    console.error(`FAIL: exit 127 lost the install sentence: ${missing.reason}`);
    failed = 1;
}
check("garbage line", M.statusFromRun(0, ndjson + "not json\n", ""), { ok: false, entries: [] });
check("empty stdout", M.statusFromRun(0, "", ""), { ok: false, entries: [] });
check("summary ok false", M.statusFromRun(0, '{"files":0,"ok":false}\n', ""), { ok: false, entries: [] });
check("entry lines but no summary", M.statusFromRun(0, ndjson.split("\n")[0] + "\n", ""), { ok: false, entries: [] });

process.exit(failed);
JS
