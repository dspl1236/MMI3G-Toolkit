# wifi-sta: Wi-Fi client (station mode) for the MMI 3G+

The MMI 3G+'s Marvell 88W8688 normally runs as the car's 2.4 GHz access
point (`uap0`, 192.168.1.1). This module makes it a Wi-Fi **client** that
joins a phone hotspot with WPA2-PSK. The factory "LAN replaces PPP" mode
then routes the unit's online services through the hotspot, with no USB
adapter and no router. Google Earth uses it, for example.

It needs a new driver. Swapping the firmware under the factory driver
cannot work, because `devnp-mv8688uap.so` is Marvell's uAP (micro access
point) driver. It sends uAP-only commands at start-up and frames packets
in the uAP TxPD layout. The station firmware expects the libertas command
set and `txpd` layout. See
[research/WIFI_STATION_MODE.md](../../research/WIFI_STATION_MODE.md).

The original work, with its source, build and evidence, is in
**[chundla/mmi3g-wifi-sta](https://github.com/chundla/mmi3g-wifi-sta)** and
**[chundla/qnx632-openssh](https://github.com/chundla/qnx632-openssh)**.
This module packages their binaries and on-unit scripts. Both repositories
rebuild every binary byte for byte; [payload/SOURCES.md](payload/SOURCES.md)
lists each file's source, checksum and licence.

## Status: alpha, one unit

Tested on **one unit only: 9411, HN+R_US_AU_K0942_3, MU 1038** (2012 Audi
A6, North America). On that unit, from 2026-10-23 to 2026-10-31, the
following passed:
- WPA2-PSK/CCMP with rekeys and reconnects;
- an iPhone hotspot at about 1.6 Mbit/s;
- the LAN-mode default route and DNS;
- the GEM screen's start button;
- the automatic join at start-up from the `lsd.sh` block, about
  3 minutes 20 s after power-on;
- back to the car's access point after a restart;
- this SD card: a first install over an earlier hand install, and an
  in-place upgrade.

**Running without the OpenSSH installation has not run on a unit yet**
(that unit always used OpenSSH's `jitter-egd`). Not yet seen at all:
- a cold start in the car away from home;
- a start-up with the hotspot off;
- a long drive.

Broadcast frames are lost (about 40 % at times) while the car's Bluetooth
streams audio; unicast is unaffected.

The installer checks that this unit's factory `devnp-mv8688uap.so`,
`dhcp.client` and `dhcp-up` match the tested unit's checksums. On any other
firmware it stops and changes nothing.

## What it changes

| Where | What | Undo |
| --- | --- | --- |
| HDD `/mnt/persistence/wifi-sta` (about 1 MB) | Driver, `wpa_supplicant`, `jitter-egd`, firmware, scripts, your hotspot configuration (root, mode 600), `boot.log` | `wifi-sta/REMOVE` card |
| `/mnt/efs-system/lsd/lsd.sh` | A five-line block marked `# BEGIN/END MMI WIFI-STA` that starts a background launcher; copy kept at `/mnt/efs-persist/wifi-sta-lsd.sh.pre` | `/mnt/efs-persist/wifi-sta-rollback.sh` (takes only the block out) |
| `/mnt/efs-system/engdefs/WifiClient.esd`, `/mnt/efs-persist/wifi-sta/gem/` | The GEM screen and its button script | `wifi-sta/REMOVE` card |
| `/HBpersistence/DLinkReplacesPPP` | The factory LAN-mode flag (empty file), if it is not already set | `wifi-sta/lan-mode.sh disable` |

The builder writes nothing to flash for this module (`installs_to_flash`
is false). The station never starts by itself until you choose it on the
GEM.

**Station mode removes the car's access point** until the next restart,
because the chip holds one firmware at a time. Phones that use the car's
Wi-Fi lose it while the station runs. To get the access point back, press
"Start-up: car access point" on the GEM, then restart.

## Use

1. **Enable the GEM** (see gem-activator) if it is not already enabled.
2. **Make `hotspot.conf`.** Copy `wifi-sta/hotspot.conf.example` on the
   built card to `wifi-sta/hotspot.conf`, and put in your hotspot's name.
   For the key, run `wpa_passphrase "Hotspot name" "passphrase"` on a
   computer and copy its `psk=<64 hex digits>` line. The file needs exactly
   one network, with `ssid=`, `psk=` and `key_mgmt=WPA-PSK`.
3. **Run the card.** Boot the unit fully, insert the card, and wait for
   the done screen. Read `var/install-*.log` on the card: it must end with
   `[wifi-sta] RESULT: OK, installed.` The installer deletes
   `hotspot.conf` from the card after storing it on the unit. The deleted
   file's bytes can stay in the card's free space until they are
   overwritten.
4. **Restart the unit.** In the GEM, open **WifiClient**:
   - **Station status**: the mode, the last start-up and the station's
     state;
   - **Start station now (access point off until restart)**: joins the
     hotspot now;
   - **Start-up: join the hotspot**: joins it at every start-up, unless
     a USB Ethernet adapter (`en5`) is plugged in. On the test unit the
     switch came about 2.5 minutes after power-on, and the join about a
     minute later;
   - **Start-up: car access point (restart to apply)**: back to the
     factory behaviour;
   - **Runner check**: checks the GEM's script runner.

Running the card again upgrades in place. The hotspot configuration and
the start-up choice stay, unless a new `hotspot.conf` is on the card.

**Remove:** put an empty file `wifi-sta/REMOVE` on the card and run it.
This removes the start-up block, the station files, the configuration and
the GEM screen. The LAN-mode flag stays. Delete `REMOVE` from the card
afterwards.

## With qnx632-openssh (optional)

The unit has no `/dev/urandom`, so `wpa_supplicant` gets its random
numbers from `jitter-egd` on `127.0.0.1:708`. This module ships
`jitter-egd` and starts it when none is running.

If [qnx632-openssh](https://github.com/chundla/qnx632-openssh) is
installed, the station uses that installation's `jitter-egd` instead. It
also starts an `sshd` on the hotspot address (port 2222, public-key only,
reachable only from the hotspot's own subnet). At start-up it waits for
OpenSSH to come up before switching. Without OpenSSH there is no shell
over the hotspot.

## If something goes wrong

- Each step logs to `var/install-*.log` on the card and stops at the first
  refusal. Steps that already ran stay done; each has its own `status`
  and rollback.
- A start that fails before the switch keeps the access point.
- A failure after the switch leaves no Wi-Fi until the restart. If the
  start-up choice is "join the hotspot", the next start-up tries again:
  press "Start-up: car access point", then restart. Plugging in a USB
  Ethernet adapter at start-up also stops the automatic start.
- `/mnt/efs-persist/wifi-sta-rollback.sh` takes the start-up block out of
  `lsd.sh` without the HDD or the card.

## Credits

The station driver, `wpa_supplicant` port and scripts are from
[chundla/mmi3g-wifi-sta](https://github.com/chundla/mmi3g-wifi-sta);
`jitter-egd` is from [chundla/qnx632-openssh](https://github.com/chundla/qnx632-openssh).
They build on:
- the Linux libertas driver, as the reference for the station protocol;
- [wpa_supplicant](https://w1.fi/wpa_supplicant/) 2.11;
- [Jitterentropy](https://github.com/smuellerDD/jitterentropy-library);
- Marvell's station firmware from
  [linux-firmware](https://gitlab.com/kernel-firmware/linux-firmware);
- [DrGER2/MMI3G-Info](https://github.com/DrGER2/MMI3G-Info);
- this toolkit's research.

Licences are in `payload/LICENSES/`.
