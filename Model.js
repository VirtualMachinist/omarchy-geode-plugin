// omarchy-geode-plugin — Model.js (G0)
//
// Status model for the bar widget. Exports the `geode` command shape and
// parses the run result; the QML side owns the actual process spawn.
//
// Command: a human verb + the vault path + `--output json`.
//
// Red lines (SPEC-omarchy G0): no token flag, no token environment
// the plugin, and none of the agent/token/serve/seal/open/mount verbs.
// Missing binary (exit 127) and an empty vault path are a failed status
// object the bar can show — never a throw, never an empty success.
.pragma library

function pluginId() {
    return "virtualmachinist.geode";
}

// The exact argv for a status listing. Human verb + vault + JSON output.
// Nothing else — no token flag, no token environment, no key material.
function listArgs(vaultPath) {
    return ["geode", "list", vaultPath, "--output", "json"];
}

// True when the widget has a vault path set.
function hasVault(vaultPath) {
    return typeof vaultPath === "string" && vaultPath.trim() !== "";
}

// Failed status the bar can show. Never throws, never ok:true.
function statusForEmptyVault() {
    return {
        ok: false,
        reason: "vault path is not set — set it in the widget settings",
        vault: "",
        entries: [],
        raw: ""
    };
}

// Parse one geode run into a status object.
//
//   code    — process exit status (127 = binary not found)
//   stdout  — captured stdout (expected JSON when code === 0)
//   stderr  — captured stderr
//
// Returns:
//   { ok: true,  vault, entries, raw }   — exit 0, stdout parsed, and the
//                                          summary document says ok:true
//   { ok: false, reason, ... }           — non-zero exit, exit 127, stdout
//                                          not JSON, or no ok:true summary
//
// stdout is either one JSON document (older geode) or newline-delimited
// geode.event.v1 documents (geode 1.2.x): one per entry carrying `path`,
// then a summary carrying `files`, which is a count. `entries` is always an
// array of path strings; the `files` count is never stored in it.
// Never throws. Never returns ok:true without parsed JSON.
function statusFromRun(code, stdout, stderr) {
    var out = typeof stdout === "string" ? stdout : "";
    var errText = typeof stderr === "string" ? stderr : "";

    if (code === 127) {
        return {
            ok: false,
            reason: "geode not found — install it with: cargo install geode-cli --version 1.2.1",
            vault: "",
            entries: [],
            raw: out
        };
    }
    if (code !== 0) {
        var why = "geode list exited with status " + code;
        if (errText.trim() !== "") {
            why += ": " + firstLine(errText);
        }
        return {
            ok: false,
            reason: why,
            vault: "",
            entries: [],
            raw: out
        };
    }

    var docs = parseDocs(out);
    if (docs === null) {
        return {
            ok: false,
            reason: "geode list printed unparsable JSON",
            vault: "",
            entries: [],
            raw: out
        };
    }

    var entries = [];
    var summary = null;
    for (var i = 0; i < docs.length; i++) {
        var doc = docs[i];
        if (typeof doc.path === "string") {
            entries.push(doc.path);
            continue;
        }
        if (Array.isArray(doc.entries)) {
            for (var j = 0; j < doc.entries.length; j++) {
                var e = doc.entries[j];
                if (typeof e === "string") {
                    entries.push(e);
                } else if (e !== null && typeof e === "object" && typeof e.path === "string") {
                    entries.push(e.path);
                }
            }
        }
        summary = doc;
    }

    if (summary === null || summary.ok !== true) {
        return {
            ok: false,
            reason: "geode list printed no ok summary",
            vault: "",
            entries: [],
            raw: out
        };
    }

    return {
        ok: true,
        entries: entries,
        raw: out
    };
}

// Convenience for the bar: full status from a run result.
function statusFor(vaultPath, code, stdout, stderr) {
    if (!hasVault(vaultPath)) {
        return statusForEmptyVault();
    }
    var st = statusFromRun(code, stdout, stderr);
    if (st.ok) {
        st.vault = vaultPath;
    }
    return st;
}

// ---- helpers ------------------------------------------------------------

// JSON objects in `out`: the whole text as one document if it parses,
// otherwise one per non-empty line. null when nothing parses, or when any
// line is not a JSON object.
function parseDocs(out) {
    var whole = tryParse(out);
    if (whole !== null) {
        return [whole];
    }
    var lines = String(out).split(/\r?\n/);
    var docs = [];
    for (var i = 0; i < lines.length; i++) {
        if (lines[i].trim() === "") {
            continue;
        }
        var doc = tryParse(lines[i]);
        if (doc === null) {
            return null;
        }
        docs.push(doc);
    }
    return docs.length === 0 ? null : docs;
}

// One JSON object, or null. Arrays and scalars are not status documents.
function tryParse(text) {
    var doc = null;
    try {
        doc = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (doc === null || typeof doc !== "object" || Array.isArray(doc)) {
        return null;
    }
    return doc;
}

function firstLine(s) {
    var str = String(s);
    var i = str.indexOf("\n");
    return i === -1 ? str : str.substring(0, i);
}
