# omarchy-geode-plugin

Omarchy shell plugin for [Geode](https://github.com/Hedronite/geode) 1.0.0. Status bar only. QML owns chrome. The `geode` CLI owns data.

Plugin id: `virtualmachinist.geode`. Kind: `bar-widget` only. No service. No install hooks.

Install the binary first, on Omarchy Linux:

```sh
cargo install geode-cli --version 1.0.0
omarchy plugin add https://github.com/VirtualMachinist/omarchy-geode-plugin.git --enable
```

The bar may show whether a vault is present. It may launch `geode tui` with no token. It must not mint keys, display a `GTOK`, or call `geode agent serve`.

The QML is not in this commit. The foundry pack is `foundry/geode` slug `omarchy` in the Atrium vault.
