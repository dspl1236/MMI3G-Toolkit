# SH4 Native Binary Development

Cross-compile SH4 binaries for the MMI3G head unit with the stock Linux
cross compiler. No QNX SDK or licence is needed.

## Prerequisites

```bash
sudo apt install gcc-sh4-linux-gnu binutils-sh4-linux-gnu
```

## Approach 1: Raw Assembly (no dependencies)

```bash
sh4-linux-gnu-gcc -nostdlib -nostartfiles -static \
    -Wl,-e,_start \
    -o hello_qnx_native \
    hello_qnx_native.S
```

Produces a 696-byte SH4 ELF using `trapa #0xfd` (QNX kernel
debug output). Output appears in the kernel debug channel.

## Approach 2: C against the unit's own libc (recommended)

The unit's `libc.so.2` is symbol-stripped, so you can't link against a copy
of it. You don't need to: link against a **stub** with the same SONAME
(`libc.so.2`) that only declares the functions you call. The linker records
them as imports, and at run time the unit's own loader
(`/usr/lib/ldqnx.so.2`) binds them to the real library. A small start-up
file initialises libc the way the unit's own programs do, so stdio, the heap
and the environment work.

PCM-Forge's [`tools/sh4-toolchain`](https://github.com/dspl1236/PCM-Forge/tree/main/tools/sh4-toolchain)
has all of it: `build.sh`, the start-up files, the stubs and two test
programs. The Porsche PCM 3.1 is the same Harman platform (SH7785, QNX
6.3.2, the same loader and libc).

```bash
git clone https://github.com/dspl1236/PCM-Forge
cd PCM-Forge/tools/sh4-toolchain
./build.sh hello_libc.c          # -> ./hello_libc, a QNX SH4 executable
```

Copy it to the unit (SD card, or over the network into `/tmp`) and run it
from a root shell:

```
# chmod +x /tmp/hello_libc; /tmp/hello_libc
[1] main reached: _init_libc returned
[2] snprintf + strlen ...
[3] malloc 64 KB, fill, check, free ...
[4] printf + getenv + envp ...
[5] all stages passed
```

Tested on an MMI 3G+ (K0942_3, MU9411) on 2026-11-26: `hello_raw` and
`hello_libc` both pass, the same binaries as on the PCM 3.1.

Limits:
- **C only:** there is no C++ runtime.
- **Declared functions only:** you can call only functions declared in a stub.
  Add a line to `stub_libc.c` (raw calls) or `stub_libc_stdio.c` (stdio, heap)
  for anything else in libc, or write a stub for another library the same way.
- **Not tried on an MMI:** the PCM tools' graphics (`libgf`, layermanager) and
  input clients talk to PCM-specific services.
- **Nothing persists:** a program run from `/tmp` or an SD card is gone after
  a reboot.

The 3G+ has no `/usr/bin/ld` to link on the unit itself, which is why this
README used to suggest it and no longer does.

## Approach 3: Java OSGi Bundles

For apps that live inside the HMI, Java OSGi bundles are the practical path.
The per3-reader module demonstrates the framework. See
`modules/per3-reader/` for a working example with DSI integration.

## Architecture Notes

- CPU: Renesas SH7785 (SH4A)
- OS: QNX Neutrino 6.3.2
- Dynamic linker: /usr/lib/ldqnx.so.2
- C library: libc.so.2 (QNX-specific)
- QNX syscall mechanism: trapa-based kernel calls via libc
  - trapa #0xfd = DebugKDOutput (r4=text, r5=len)
  - trapa #0xfe = DebugBreak
