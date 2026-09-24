// omarchy-geode-plugin — BarWidget.qml (G1)
//
// Omarchy bar chrome for Geode. Runs the Model.js `geode` command shape
// (`list <vault> --output json`) in a Quickshell Process, shows the
// resulting status (`ok`, `reason`), and on click launches `geode tui`
// with the vault path and WITHOUT `--token`.
//
// Red lines (SPEC-omarchy G1): this widget never touches the agent
// plane or any mutating vault verb; no token of any kind; no secrets
// in QML. Data comes from the `geode` CLI via Model.js; this file owns
// chrome only.

import QtQuick
import Quickshell
import Quickshell.Io

import "Model.js" as Model

Item {
    id: root

    // Host settings. Lathe Bar.qml injectProps assigns `target.settings =
    // moduleSettings` when the widget declares this property — it never
    // assigns vaultPath directly. The manifest schema key is vaultPath.
    property var settings: ({})

    // Derived from settings.vaultPath (schema key). Empty/missing keeps
    // the empty-vault failed status.
    readonly property string vaultPath:
        (settings && typeof settings.vaultPath === "string")
        ? settings.vaultPath : ""

    // Status from Model.js. Starts as the empty-vault failed status;
    // a run only replaces it when a vault path is set.
    property var status: Model.statusForEmptyVault()

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 22

    // Fold a finished run into the bar status via Model.js.
    function refresh(code, stdout) {
        status = Model.statusFor(vaultPath, code, stdout, "");
    }

    function rerun() {
        if (!Model.hasVault(vaultPath)) {
            status = Model.statusForEmptyVault();
            return;
        }
        geodeRun.command = Model.listArgs(vaultPath);
        geodeRun.running = true;
        // A missing `geode` binary never emits `exited`: the run stays
        // running=false (pid null). That is the failed-to-start shape on
        // Quickshell 0.3.0. 127 is
        // the not-found code; Model turns it into the missing-binary
        // reason instead of leaving the empty-vault status up.
        if (!geodeRun.running) {
            status = Model.statusFromRun(127, "", "");
        }
    }

    onSettingsChanged: rerun()
    Component.onCompleted: rerun()

    Process {
        id: geodeRun

        // Set by rerun(): Model.listArgs(vaultPath) — human verb + vault
        // path + --output json. No token flag, no token env of any kind.
        command: []

        // Collect stdout; it is read in onExited only — never refreshed
        // from here (Process has no exitCode property).
        stdout: StdioCollector {
            id: collector
        }

        // The single fold point: exit code + the collector text. Exit 0
        // with JSON keeps ok:true. Missing-binary runs never reach here
        // (no `exited` fires); rerun() catches those via the running flag.
        onExited: function (code) {
            root.refresh(code, collector.text);
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6

        Text {
            text: root.status.ok ? "◆" : "◇"
            color: root.status.ok ? "#7dcfff" : "#f7768e"
            font.pixelSize: 13
        }

        Text {
            text: root.status.ok
                  ? "vault ready"
                  : (root.status.reason || "unavailable")
            color: root.status.ok ? "#c0caf5" : "#f7768e"
            font.pixelSize: 12
        }
    }

    MouseArea {
        anchors.fill: parent

        onClicked: function (mouse) {
            if (!mouse || mouse.button !== Qt.LeftButton) {
                return;
            }
            // Token-free launch: `geode tui` + vault path only. Never
            // `--token`; never any agent-plane or mutating verb from chrome.
            Quickshell.execDetached(["geode", "tui", root.vaultPath]);
        }
    }
}
