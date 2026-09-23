# Experimental persistent console (MMI3G+)

`tools/persistent_telnet.sh` is an **opt-in boot helper**, not an SD installer.
It is not included in the default SD build. It starts a dedicated `inetd`
configuration for a passwordless root shell on TCP 2323. The name follows
the project's existing "telnet 2323" terminology; this is **raw TCP**, without
TELNET negotiation, encryption, authentication, or a proper terminal.

## Security and scope

- Use only on your own unit, on an isolated, trusted direct Ethernet link.
- The listener is **not bound to 172.16.42.1**: it can accept connections on
  all reachable interfaces. The IP check is only a startup prerequisite.
  Disconnect/disable other network paths before enabling it. Never forward
  this port from the internet or expose it to an untrusted Wi-Fi/router LAN.
- This is not SSH, a recovery bootloader, or a brick-proof recovery channel.
  It depends on QNX, EFS, networking and the boot script that invokes it.
- Editing a boot script can prevent normal startup. Have a verified backup
  and a recovery method independent of that script before making it persistent.
- Supported *test context*: MMI3G+ `HN+R_EU_AU_K0900`, QNX 6.3.2, SH7785.
  The runtime architecture check does not identify firmware compatibility.
  Other firmware, MIB/MIB2, and other QNX targets are not validated.

## What it does

The helper normalizes the working directory and library search path instead
of inheriting the HMI/J9 launch environment. It ignores SIGHUP and disconnects
standard input. It waits at most 30 three-second intervals for the existing
`devc-pty`, system `inetd` (without config arguments), and IPv4 172.16.42.1.
It does not start, stop, or reconfigure those prerequisites.

It writes only flat RAM files in `/dev/shmem`. A lock prevents overlapping
helper invocations. An existing dedicated normal/debug `inetd` is left alone;
a conflicting config is rejected. This does not detect every possible owner
of port 2323: inspect the network/process state first. There is no restart loop.
Neither an existing process nor `START_REQUESTED` proves that a shell works.

There are no network driver changes, flash remounts, account/password changes,
firmware updates, J9 restarts, or boot-script edits in the helper itself.

## Stage and test before persistence

1. Establish a working recovery session and save off-unit backups of the boot
   script and any existing console helper/configuration. Keep the stock
   login service unchanged. Do not install alongside another 2323 starter.
2. Transfer this script to a verified writable location, initially SD or RAM.
   Compare `cksum` on the computer and unit. Running the command below without
   the flag prints the warning and does nothing.
3. With the prerequisites already working, invoke the staged script:

   ```sh
   /bin/ksh /verified/path/persistent_telnet.sh --allow-unauthenticated-root
   ```

4. From the directly connected computer (configured separately as
   172.16.42.2/24), open a fresh session:

   ```sh
   nc 172.16.42.1 2323
   ```

   Then type `echo CONSOLE_TEST_123`, `uname -srm`, and `exit`, each on its own
   line. Confirm the marker and QNX output actually return. Repeat in a second
   fresh connection. A successful TCP connect alone is not a successful test.
   `ksh -i` may warn about missing tty/job control; that warning alone does not
   establish why a connection closed. Starting `devc-pty` also does not itself
   allocate a terminal for this raw socket.
5. Inspect `/dev/shmem/mmi-persistent-telnet.log`. On failure, collect it and
   the process listing; do not repeatedly restart all `inetd` processes.

## Make it persistent (manual, firmware-specific)

Only after the session test, place the verified script on EFS using your
unit's established backup/write/read-only-remount procedure. This repository
does not automate that procedure or choose a boot insertion point for you.

On the K0900 test unit an existing, reviewed background hook in `lsd.sh`
called an EFS helper. An equivalent explicit opt-in hook for this script is:

```sh
[ ! -x /mnt/efs-system/a7net/persistent_telnet.sh ] || \
    /mnt/efs-system/a7net/persistent_telnet.sh --allow-unauthenticated-root &
```

This is an example for that layout, **not a command to append blindly**.
Preserve the original HMI startup and its exit behavior. Replace/review any
older console hook instead of adding duplicates. Make the helper executable;
verify the deployed contents and the boot-script syntax before rebooting.
Merely copying the helper onto SD does not install persistence.

After a controlled reboot without the SD card, repeat the two command-roundtrip
tests above and verify the factory UI/audio remain normal. Then test a normal
power cycle separately; an MMI reset is not evidence of a cold boot.

To disable persistence, remove only your added hook (or restore the verified
original boot script), using the same controlled EFS procedure. Reboot to
clear the RAM config/listener, then check that 2323 is closed. Removing the
helper file alone does not terminate a currently running listener. Do not
use a global `slay inetd`: that also kills the stock service.

## Validation status

The startup pattern (normalized launch context, bounded readiness wait,
dedicated `inetd` and `ksh -i`) was exercised on one K0900 unit. A working
2323 console after a later MMI restart was **user-reported**, not independently
captured as a post-reboot command roundtrip. This upstream version adds
opt-in/platform guards, locking and config-conflict checks; those changes
have host-side mock tests, not a new on-car validation. No cross-firmware
or recovery guarantees are made.

Run the tests with `python3 -m unittest discover -s tests -v`. The helper tests
substitute temporary paths and mock the QNX commands; they do not start a
network listener or emulate QNX process/signal behavior. To exercise a host
Korn shell as well, run
`MMI_TEST_SHELL=/bin/ksh python3 -m unittest discover -s tests -p test_persistent_telnet.py -v`.
