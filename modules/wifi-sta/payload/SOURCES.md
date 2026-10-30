# Where these files come from

Original work: **[chundla/mmi3g-wifi-sta](https://github.com/chundla/mmi3g-wifi-sta)**
(commit `11f7001`) and **[chundla/qnx632-openssh](https://github.com/chundla/qnx632-openssh)**
(commit `602b297`, the `openssh` submodule of the former). Both repositories
reproduce every binary below byte for byte with the QNX 6.3.2 SDK; see their
READMEs. The research, evidence and validation limits are in
`docs/wifi-client/wifi-client-mode.md` there.

| File | POSIX `cksum` | Source | Licence |
| --- | --- | --- | --- |
| `devn-mv8688sta.so` | `3938534867 64931` | mmi3g-wifi-sta `wifi-sta/build-driver.sh` | GPL-2.0-only (`LICENSES/GPL-2.0.txt`) |
| `mv8688-ctl` | `3277080864 11450` | mmi3g-wifi-sta `wifi-sta/build-driver.sh` | GPL-2.0-only |
| `mv8688-probe` | `2747790827 77195` | mmi3g-wifi-sta `wifi-sta/build-probe.sh` | GPL-2.0-only |
| `wpa_supplicant` | `2366746706 491332` | wpa_supplicant 2.11 with mmi3g-wifi-sta `wifi-sta/wpa/` (`build-wpa.sh`) | BSD-3-Clause (`LICENSES/wpa_supplicant-COPYING.txt`, `LICENSES/mmi3g-wifi-sta-BSD-3-Clause.txt`) |
| `jitter-egd` | `2336099037 35856` | qnx632-openssh `build-jitter.sh`, Jitterentropy 3.7.0 | BSD-2-Clause (`LICENSES/qnx632-openssh-BSD-2-Clause.txt`), Jitterentropy BSD-3-Clause (`LICENSES/jitterentropy-LICENSE.bsd.txt`) |
| `sd8688.bin` | `251454034 259172` | [linux-firmware](https://gitlab.com/kernel-firmware/linux-firmware) `mrvl/sd8688.bin` (checked against commit `08624cd0`) | `LICENSES/LICENCE.Marvell` |
| `sd8688_helper.bin` | `1538620194 2616` | linux-firmware `mrvl/sd8688_helper.bin` | `LICENSES/LICENCE.Marvell` |
| `sta-mode.sh`, `sta-boot.sh`, `boot-launch.sh`, `sta-install.sh`, `gem-install.sh`, `lan-mode.sh`, `WifiClient.esd`, `gem.sh` | see `CKSUMS` | mmi3g-wifi-sta `wifi-sta/` | GPL-2.0-only |

The Marvell firmware is redistributed under `LICENCE.Marvell`. It may be
used only with Marvell silicon (the head unit's 88W8688), and must not be
reverse engineered.

The station driver was written using the Linux libertas driver as the
reference for the station protocol. No libertas code is copied, but the
driver is under libertas' licence, GPL-2.0, to be safe. Its source is the
repository above.
