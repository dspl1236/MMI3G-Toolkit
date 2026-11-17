# Cluster navigation display (MMI 3G High → instrument cluster)

How an MMI 3G High draws turn-by-turn guidance on a CAN-connected instrument
cluster (the centre display of the normal cluster, not the big-screen "High
Kombi" of the A6/A7/A8, which gets its picture over MOST). Found in the
firmware of **8R0906961CP, HNav_US_K0133_3** (MU9308). Other 3G High versions
are expected to match; check before relying on addresses.

Context: [issue #19](https://github.com/dspl1236/MMI3G-Toolkit/issues/19).
Status: decoded from firmware only. **Not yet checked against a CAN log.**

## The chain

| Step | Where | What |
|---|---|---|
| 1 | Java HMI, `lsd.jxe` | `de/audi/tghu/combi/app/CombiDriver` builds three cluster frames: navigation (`CombiNaviFrame`: turn arrow "RGI", distance bar, distance to turn, street, distance to destination, ETA), a 4-line list (`CombiListFrame`, used by radio/phone/media) and a status line (`CombiStatusFrame`) |
| 2 | DSI | `org/dsi/ifc/datadisplay/DSIDataDisplay` → service `SPHDataDisplay` (`RQST_setManeuver`, `RQST_setDistanceBar`, `RQST_setStreetName`, `RQST_showFrame` …) |
| 3 | `MMI3GApplication` | `CDataDisplayPresCtrl` (log prefix `[DD]`) checks the requests, keeps a queue and sends each item as a MOST function message (`framework_frameworkcomponents_most_CHBParaStream`) |
| 4 | I/O chip, `MuIOC/V850app.bin` | The V850 is itself a MOST node (`CfMost`). Its `cfappgateway` wraps each item into a TP2.0 message (`cfTP20`) to the cluster |
| 5 | CAN | **Fixed TP2.0 channel: 0x490 (MMI → cluster), 0x491 (cluster → MMI)** |

The navigation side feeds step 3 through the MOST Navigation property
`RG_NextManeuverDescriptorKombiDisplay` (`CSPHNavAudiNG3Impl`), which copies
the nav engine's bytes as they are.

## Turn arrow ("RGI") element

```
DC <length> <symbol> <direction> [arm bytes ...]
```

- `CDataDisplayPresCtrl::requestSetManeuver` rejects a stream that doesn't start
  with `0xDC` ("WRONG maneuver description").
- The nav engine's serializer (`CRGWgtAudiManeuverDescriptor`, "KD3",
  `0x82eb630`) produces `<symbol> <direction> [arms]` without the `DC <length>`
  header. The header is most likely added by the Java side (not confirmed).

### Symbol byte (`RG_MET_*` element types, name switch at `0x833f6e0`)

| Byte | Meaning | Byte | Meaning |
|---|---|---|---|
| `00` | No symbol | `13` / `14` | Fork, 2-way / 3-way |
| `01` | No info | `15` / `16` | Roundabout (right- / left-hand traffic) |
| `02` | Direction to destination | `17` / `18` | Square (right / left) |
| `03` | Arrived | `19` | U-turn |
| `04` | Near destination | `1A` / `1B` | Exit roundabout (right / left) |
| `05` | Arrived, destination off map | `1C` | Prepare turn |
| `06` | Off road | `1D` | Prepare roundabout |
| `07` | Off map | `1E` | Prepare square |
| `08` | No route | `1F` | Prepare U-turn |
| `09` / `0A` | Calculating / recalculating route | `20` / `21` | Exit right, ramp up / down |
| `0B` | Follow street | `22` / `23` | Michigan turns (US) |
| `0C` | Change lane | `80`–`FF` | Side streets |
| `0D` | Turn | | |
| `0E` | Turn onto main road | | |
| `0F` / `10` | Exit right / left | | |
| `11` / `12` | Service road right / left | | |

`requestSetManeuver` logs `00`, `01`, `06`, `07`, `08` by name and calls
`22`/`23` "might be unsupported".

### Direction byte (converter at `0x82ec5a0`)

An angle in 1/256 of a turn, counter-clockwise, rounded to 16 steps of 22.5°:
`byte = (round((deg + 360) / 22.5) mod 16) << 4`.

| Byte | Direction |
|---|---|
| `00` | straight ahead |
| `40` | left (90°) |
| `80` | back |
| `C0` | right (270°) |
| `FF` | none |

### Arm bytes

After the direction, the junction's roads follow as direction bytes. Some
markers (`41`/`C1`, `80`, `60`/`A0`) are not fully understood yet. A
roundabout's exit number has no byte of its own; it probably comes from the
position in the arm list. Builders per maneuver type: `0x82eb1f4`–`0x82eba3c`
(setters `0x82eadd0` symbol, `0x82eade0` direction, `0x82eadb0` add arm,
`0x82eadf8` clear).

### Test patterns

The engineering menu's built-in test (`callBack_drawRGI_Proxy_fest`, `0x88bca70`):

| Test | Bytes |
|---|---|
| No route | `DC 02 08 50` (`50` = bearing to the destination, 112.5°) |
| Follow street | `DC 02 0B FF` |
| Turn left | `DC 03 0D 40 00` |
| Michigan 1a / 1b | `DC 02 22 40` / `DC 02 22 C0` |
| Michigan 2a / 2b | `DC 02 23 40` / `DC 02 23 C0` |

## CAN side (V850 I/O chip)

`V850app.bin` of this version loads at **0x10040** (file offset = address −
0x10040). At 0x10000 the pointer tables don't line up. Addresses below use
0x10040.

### TP2.0

- TP2.0 runs in the I/O chip. The MMI's own TP2.0 address is `0x4D`; setup
  requests to it are answered on `0x24D` (dispatcher `FUN_00033d38`, setup
  handler `FUN_00033766`).
- Three channels (ROM table `0x10f3a`). **Index 0 is fixed: TX 0x490, RX
  0x491, opened with no setup frames** (`FUN_00032bea`). It carries the cluster
  display. Indexes 1 and 2 are opened on demand (RX `0x2D0`/`0x2D1`), for
  example for KWP2000 diagnostics.
- Block size up to 15. Keep-alive `A3` every 100 ticks (`FUN_00032ce8`), `A4`
  handled, `A8` = disconnect. ROM timings at `0x10f04`: 100, 10, 15.

### Display elements

Each TP2.0 message carries one element: **`[ID][length][data]`**. The I/O chip
only wraps what the main processor sends (it never compares against `0xDC`).
When the link comes up it sends `00 4D 02`.

| ID | Data | Meaning |
|---|---|---|
| `00` | `4D xx` | handshake (confirmed) |
| `02` | `48` | ? |
| `30`, `36` | 1 byte | style? phone signal? (inferred) |
| `32` `34` `38` `3C` `3A` | 1 byte | probably show/hide of the frames (inferred) |
| `90` | variable | probably list / status-line text (inferred) |
| `94` | 3 bytes | cursor? (inferred) |
| `DC` | variable | **turn arrow** (confirmed) |
| `DE` | 1 byte / none | draw / remove distance bar (strong inference) |
| `E0`, `E2`, `E4` | various | probably street name, distances, ETA (unassigned) |

Element handlers: function-object array at `0x113a0`–`0x11560`. Messages from
the cluster go to `FUN_00035518` (types `01`, `03` → MOST `0x300`, `0x302`;
type `09` is answered with `20 C0 …`).

## What a log needs

Log the MMI's CAN (listen-only) from switch-on, then a guided route with a few
turns and an arrival. Filter on **0x490 / 0x491**: the TP2.0 data frames there
carry the elements above. Matching each element ID to what the cluster shows
completes the table.

## Not yet known

- Which element ID is which for everything except `00` and `DC`.
- The arm-list markers in the turn arrow.
- Where exactly the `DC <length>` header is added.
