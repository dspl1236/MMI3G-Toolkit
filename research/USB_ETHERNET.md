
## Speed Discovery (DrGER2, May 2026)

### Root Cause: Harman hardcodes speed=10 in umass-enum config

The ASIX driver speed is set by `vdev-medialauncher` which reads
`/etc/umass-enum_def.cfg` (IFS, read-only):

```
vendor=0x0b95,device=0x7720,type=ETH,driver=devn-asix.so,args=speed=10 duplex=1,netif=5,netip=172.16.250.248,netmsk=255.255.0.0
```

All five ASIX entries in the config use `speed=10 duplex=1`.
This means **every MMI3G with USB ethernet runs at 10baseT** regardless
of the AX88772A's 100Mbps capability.

### Process chain (from sloginfo)

1. `vdev-medialauncher` detects USB insertion (PID from IFS)
2. Reads device match from `/etc/umass-enum_def.cfg`
3. Starts `io-pkt-v4-hc -d devn-asix.so` with `speed=10`
4. `multicored` assigns IP 172.16.250.248/16 on en5
5. If `/mnt/efs-persist/usedhcp` exists → NWSProcess starts DHCP client

### Fix approaches

**Immediate (our LTE scripts):**
Our scripts detect if en5 already exists (from vdev-medialauncher)
and upgrade the speed via `ifconfig en5 media 100baseTX mediaopt full-duplex`.
Falls back to killing io-pkt and restarting with speed=100.

**Persistent (EFS overlay — untested):**
QNX union filesystem may allow overlaying the config:
```
/mnt/efs-system/etc/umass-enum_def.cfg
```
with `speed=100` replacing `speed=10`. If vdev-medialauncher reads
from the overlay path, this would fix speed system-wide without
needing to run any scripts.

**NWSProcess hook:**
DrGER suggests adding speed change to:
```
/mnt/efs-system/pss/nws/usr/bin/NWSProcess.sh
```
for persistence across reboots.

### Attribution

Discovery and analysis by DrGER2 (Gary). Config file contents,
process chain, and sloginfo traces from his K0821 research.
