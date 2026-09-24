# omarchy-geode-plugin

Omarchy shell plugin for [Geode](https://github.com/Hedronite/geode) 1.0.0. Status bar only. QML owns chrome. The `geode` CLI owns data.

Plugin id: `virtualmachinist.geode`. Kind: `bar-widget` only. No service. No install hooks.

## Install

Install the binary first, on Omarchy Linux — the plugin does **not** install it:

```sh
cargo install geode-cli --version 1.0.0
omarchy plugin add https://github.com/VirtualMachinist/omarchy-geode-plugin.git --enable
```

Then set the vault path in the bar widget's settings. The plugin reads no vault files itself; it shells the `geode` CLI (`list --output json`) via `Model.js`.

## What the bar does

- Shows the model status from `Model.js`: vault ready, missing `geode` binary, or vault path unset — fail closed, never a silent empty success.
- A click launches `geode tui` with the vault path and **without** `--token`.

## Red lines

- **No token.** No token flag, no token armor, no token env written anywhere by this plugin.
- **No agent plane.** No agent socket, no MCP from QML — the agent plane stays out of Omarchy chrome.
- **No install hooks.** The installer never runs plugin code, never sudo, never pacman. Binary install is the separate `cargo install` step above.
- QML calls only human verbs (`list`, `tui`) — never any agent-plane or mutating vault verb.

The foundry pack is `foundry/geode` slug `omarchy` in the Atrium vault.
