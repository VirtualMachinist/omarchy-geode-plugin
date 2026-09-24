// omarchy-geode-plugin — Model.js (G0)
//
// Status model for the bar widget. Exports the `geode` command shape and
// parses the run result; the QML side owns the actual process spawn.
//
// Command: a human verb + the vault path + `--output json`.
//
// Red lines (SPEC-omarchy G0): no `--token`, no `GEODE_TOKEN` written by
// the plugin, and none of the agent/token/serve/seal/open/mount verbs.
// Missing binary (exit 127) and an empty vault path are a failed status
// object the bar can show — never a throw, never an empty success.
.pragma library

function pluginId() {
    return "virtualmachinist.geode";
}

// The exact argv for a status listing. Human verb + vault + JSON output.
// Nothing else — no --token, no GEODE_TOKEN, no key material.
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
//   { ok: true,  vault, entries, raw }   — stdout was valid JSON
//   { ok: false, reason, ... }           — non-zero exit, exit 127, or
//                                          stdout was not JSON
// Never throws. Never returns ok:true without parsed JSON.
function statusFromRun(code, stdout, stderr) {
    var out = typeof stdout === "string" ? stdout : "";
    var errText = typeof stderr === "string" ? stderr : "";

    if (code === 127) {
        return {
            ok: false,
            reason: "geode not found — install it with: cargo install geode-cli --version 1.0.0",
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

    var doc = null;
    try {
        doc = JSON.parse(out);
    } catch (e) {
        doc = null;
    }
    if (doc === null || typeof doc !== "object") {
        return {
            ok: false,
            reason: "geode list printed unparsable JSON",
            vault: "",
            entries: [],
            raw: out
        };
    }

    var entries = [];
    if (doc.entries && doc.entries.length !== undefined) {
        entries = doc.entries;
    } else if (doc.files !== undefined) {
        entries = doc.files;
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

function firstLine(s) {
    var str = String(s);
    var i = str.indexOf("\n");
    return i === -1 ? str : str.substring(0, i);
}
