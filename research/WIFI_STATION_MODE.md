# Wi-Fi station mode on the MMI 3G+ (88W8688)

Summary of an investigation that turned the built-in access point into a
Wi-Fi client of a phone hotspot. The full notes are in
[chundla/mmi3g-wifi-sta `docs/wifi-client/wifi-client-mode.md`](https://github.com/chundla/mmi3g-wifi-sta/blob/main/docs/wifi-client/wifi-client-mode.md),
with every phase's plan, hardware result, evidence and the open questions.
The source, build and binaries are in that repository and in
[chundla/qnx632-openssh](https://github.com/chundla/qnx632-openssh). The
[`wifi-sta` module](../modules/wifi-sta/README.md) installs it.

**Scope.** Everything here was established on one unit, 9411,
HN+R_US_AU_K0942_3, MU 1038 (QNX 6.3.2, SH7785), from its saved backups
and by running on it. Nothing has been checked on another train, region or
MU.

## Why the firmware swap cannot work

[DATA_CONNECTIVITY_OPTIONS.md](DATA_CONNECTIVITY_OPTIONS.md) proposed
loading the libertas station firmware (`sd8688.bin`) under the factory
driver. Decompiling `devnp-mv8688uap.so` (Ghidra) showed why that fails:
- **The driver is uAP-only.** It is Marvell's micro-access-point driver,
  and it sends uAP commands (for example `0x00b0`) while bringing the
  interface up. Station firmware does not implement them.
- **The data path is uAP-only.** `mv8688uap_pb_htoc` frames every packet
  with the uAP TxPD (BSS type 1, packet offset 20). The station firmware
  expects the libertas `struct txpd` (packet offset 24).
- **`/tmp/FwImage` is never read.** The driver builds
  `<fwpath>/FwImage/sd8688_ap.bin`, and its default `fwpath` is `/tmp`, but
  the factory mount passes `fwpath=/lib/dll`.
- **The firmware is not reloaded.** It is downloaded only after a chip
  reset, and the factory mount uses `resetmask=0` ("Skip FW download").
- **The driver is not a process.** It is a DLL inside `io-pkt-v4-hc`, so
  `slay -f devnp-mv8688uap` does nothing useful. Killing that `io-pkt`
  also drops MOST IP (`mam0`) and `pf`.

## What was built

```text
phone hotspot (2.4 GHz, WPA2-PSK/CCMP)
        │ 802.11b/g
88W8688 running sd8688.bin (libertas station firmware, linux-firmware)
        │ SDIO, Harman FPGA module 53
devn-mv8688sta.so   new io-net driver, hosted by the factory devnp-shim in io-pkt as en6
   ├─ FPGA SDIO host (behaviour recovered from the factory driver)
   ├─ SDIO card layer (PIO), helper + firmware download
   └─ libertas command/event and txpd/rxpd layer; scan, join, keys, link state
wpa_supplicant 2.11  driver backend for it, BPF l2_packet, random numbers from jitter-egd
factory dhcp.client + dhcp-up in LAN mode   lease → default route and DNS
sta-mode.sh   start / status / stop, a keeper that rejoins; pf blocks inbound on en6
GEM screen    status, start now, start-up choice, back to the access point
```

Findings that matter to anyone building native code for this unit:
- **Toolchain.** Use the QNX 6.3.2 SDK (`sh-unknown-nto-qnx6.3.0-gcc`
  3.3.5). The 6.5 toolchain links `libc.so.3`, and the unit has only
  `libc.so.2`.
- **Randomness.** The unit has no `/dev/random` or `/dev/urandom`.
  `jitter-egd` serves Jitterentropy over the EGD protocol on
  `127.0.0.1:708`.
- **No second stack.** An io-net driver can run inside the running
  `io-pkt` through the factory `devnp-shim.so`, so there is no second
  network stack.
- **One firmware at a time.** The chip holds one firmware. The access
  point comes back cleanly only through a restart: a manual re-mount of
  the factory driver gives `uap0` no network name.
- **The LAN-mode flag.** The empty file `/HBpersistence/DLinkReplacesPPP`,
  read at start-up, makes the factory `dhcp-up` keep a lease's default
  route, write `resolv.conf` and add the DNS-redirect anchors. The HMI
  then treats the connection as established. This is the same flag the
  `usb-net` module's `lte` mode sets.
- **Broadcast loss.** While the car's Bluetooth streams audio, about 40 %
  of broadcast frames are lost at times. Unicast is unaffected.

Throughput is about 1.6 Mbit/s, measured as 10 MB in 52 s over an iPhone
hotspot. PIO over the FPGA SDIO host is the limit.

## Not established

- Logs from the car: the owner reported a cold start away from home, a
  start-up with the hotspot off and a long drive all working (2026-10-31),
  but none of them was logged.
- The station without the OpenSSH installation, using the module's own
  `jitter-egd`.
- The Audi connect info services and online POI search do not use the
  connection ("No SIM card"), and Google Earth does.
- Any unit other than the one above.
