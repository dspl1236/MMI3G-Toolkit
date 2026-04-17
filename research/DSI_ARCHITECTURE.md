# DSI IPC architecture (Distributed Service Infrastructure)

DSI is Harman Becker's RPC/IPC framework layered over QNX `MsgSendv`.
Everything in the MMI3G HMI that crosses a process boundary does it
over DSI: the 10.7 MB `MMI3GApplication` binary is full of DSI client
and server code talking to `servicebroker` (process #95), to
`dev-ipc` (process #3), to the persistence daemon that backs
`/HBpersistence`, to the IOC (secondary V850 MCU), and to sibling
HMI processes (`MMI3GMedia`, `MMI3GNavigation`, etc).

This document catalogs the DSI class hierarchy and the event-pattern
the framework uses, with specific entry points identified by symbol
in the actual binary. All symbol names below were extracted from
`/usr/apps/MMI3GApplication` via `strings` on our IFS extraction of
MU9411 K0942_4 variant 41.

See also:
- `HMI_ARCHITECTURE.md` for the process-level picture
- `PER3_READER.md` for the Java-side equivalent (what per3-reader hooks)
- `PER3_ADDRESS_MAP.md` for the persistence namespace key map

## The Proxy / Stub / Event pattern

Every DSI service follows a standardized five-class pattern:

```
C<ServiceName>Adapter            ← abstract interface (names the service)
C<ServiceName>AdapterProxy       ← client-side: translates calls → MsgSendv
C<ServiceName>AdapterStub        ← server-side: receives messages, dispatches
C<ServiceName>AdapterRequestEvent      ← marshalled request payload
C<ServiceName>AdapterResponseEvent     ← marshalled response payload
C<ServiceName>AdapterNotificationEvent ← marshalled async notification
```

Confirmed complete by `grep`-ing `MMI3GApplication` for the `CSPH`
(Speech Processing Handler) family:

```
CSPHRSUAdapter
CSPHRSUAdapterProxy
CSPHRSUAdapterStub
CSPHRSUAdapterRequestEvent
CSPHRSUAdapterResponseEvent
CSPHRSUAdapterNotificationEvent
```

The `RSU` infix stands for **Remote Service Unit** — Harman's term for
"the class of classes that wrap a DSI service endpoint."

## DSI core framework classes

From `MMI3GApplication` strings, grouped by role:

### Transport layer

```
CDSIChannel             Wraps a QNX channel (ConnectAttach/MsgSend pair)
CDSIMsgChannel          Channel specialized for request/response RPC
CDSIMsgChannelThread    Dedicated thread that parks on MsgReceive
CDSICtrl                Control plane — service registration, liveness
CDSIExceptionMap        Maps errno/DSI-error codes to typed C++ exceptions
```

### Access layer (used by MMI3GApplication to dial out)

```
CDSIAccessProxy                 Generic access client
CDSIAccessRequestEvent          Request marshalling
CDSIAccessResponseEvent         Response demarshalling
CDSIAccessNotificationEvent     Async notification events
```

### Service layer (used by MMI3GApplication to serve interfaces it provides)

```
CDSIServiceAdapter              Abstract service registration
CDSIServiceProxy                Client-facing stub
CDSIServiceStub                 Server-facing dispatch
CDSIServiceRequestEvent
CDSIServiceResponseEvent
CDSIServiceNotificationEvent
```

### Shell layer (management/debug surface)

```
CDSIShellProxy                  Debug shell RPC
CDSIShellRequestEvent           (`pidin`-style introspection from remote)
CDSIShellResponseEvent
CDSIShellNotificationEvent
CDSIShellSA                     Shell-side service adapter
```

## Concrete RSU adapters in MMI3GApplication

Every one of these maps to a distinct DSI service that MMI3GApplication
either consumes or provides. Each comes with the five-class pattern
from above.

```
CAMEngineeringRSUAdapter              Audio Management engineering surface
CAudioManagementRSUAdapter            Main audio routing / mixer control
CAudioManagementDevCtrlRSUAdapter     Audio device-control (codec/amp state)
COnOffRSUAdapter                      Power / ignition state events
CPersistenceRSUAdapter                DSI persistence (read/write adapt data)
CPlayerEngineRSUAdapter               Media playback engine
CSPHRSUAdapter                        Speech Processing Handler
CSoundRSUAdapter                      Volume / balance / bass / treble / subwoofer
                                      / surround / fader / tone controls
```

## Persistence API (the thing per3-reader bridges)

The `CPersistenceRSUAdapter` service exposes this operation set
(8 methods — a 2D matrix of `request{Read,Write}` × `{Int,String,Array,Buffer}`):

```c++
// Typical signatures, reconstructed from log strings in MMI3GApplication:

status_t requestReadInt(uint64_t key, int32_t& value);
status_t requestReadString(uint64_t key, string& value);
status_t requestReadArray(uint64_t key, vector<...>& array);
status_t requestReadBuffer(uint64_t key, void* buf, size_t& len);

status_t requestWriteInt(uint64_t key, int32_t value);
status_t requestWriteString(uint64_t key, const string& value);
status_t requestWriteArray(uint64_t key, const vector<...>& array);
status_t requestWriteBuffer(uint64_t key, const void* buf, size_t len);
```

The `key` is 64-bit (`key(0x%llx)` in log format strings) which is
wider than the 32-bit addresses our `PER3_ADDRESS_MAP.md` documents —
the upper 32 bits are a namespace/class-id and the lower 32 are the
address within that namespace. Exact encoding TBD; worth a follow-up
RE session.

## PresCtrl — the HMI's own persistence façade

DSI's `CPersistenceRSUAdapter` is the raw wire protocol. The HMI
wraps it with a **Presentation Controller** abstraction (`PresCtrl`)
that knows about HMI concepts rather than generic keys. Identified
families:

```
CIOCPresCtrl                    Base class — talks to the V850 IOC MCU
CIOCPresCtrlAmiCable            AMI cable / MDI-USB adapter state
CEngineeringAccessPresCtrlNavi  GEM access to nav-related per3 values
CEngineeringAccessPresCtrlSystem   ... system-wide per3 values
CEngineeringAccessPresCtrlTelephony  ... telephony per3 values
CEngineeringAccessPresCtrlTraceScope ... trace/debug controls
CEngineeringAccessPresCtrlConfig     ... configuration values
CPersistencePresCtrl            Client-side wrapper around CSPHPersistenceProxy
CSPHPersistenceProxy            Speech-processing-handler persistence proxy
CSPPersistenceEngineeringProxy  Speech-processing engineering proxy
```

Log prefixes in the binary:
- `!PPC:` — error-level Presentation Controller log
- `#PPC:` — info-level Presentation Controller log

The `CEngineeringAccess*` variants are specifically what GEM screens
invoke when they show per3 values. This is precisely the code path
`long-coding` module's displayed values flow through today.

## Native persistence classes (beyond the RSU/PresCtrl split)

Standalone persistence classes that aren't DSI-wrapped but write
directly to `/HBpersistence`:

```
CAudioMngPersistence            Audio manager state (amp settings, sound profiles)
CIOCPresCtrlPersistence         IOC controller state
CRSUDevicePersistence           RSU device enumeration cache
CTVTunerPersistence             TV tuner state (present in all builds, used only
                                in certain variants)
HBTracePersistence              Harman trace subsystem state
RsuPersistence                  Base RSU persistence interface
SPHPersistence                  Speech Processing Handler persistence (v20.0)
```

Each has corresponding `.cpp` files referenced in symbol tables:
`CAudioMngPersistence.cpp`, `CIOCPresCtrlPersistence.cpp`,
`CRSUDevicePersistence.cpp`, `CTVTunerPersistence.cpp`,
`SPHPersistence.cpp`.

## How to build a native DSI client

For someone wanting to build a custom native tool that speaks DSI
(for example, a command-line `per3` tool that would make per3-reader's
Java path unnecessary), the minimum set needed:

1. **Link against the DSI native libraries.** From
   `/mnt/ifs-root/usr/lib/` we extracted:
   - `libdsiservice.so`
   - `libdsiClient.so` (if present on your variant)
   - `libdsiInterfaceBase.so`
   The public symbol surface of these is the real target spec.

2. **Include headers.** The QNX-standard DSI headers (`dsi/ifc/*.h`)
   are NOT in the leaked openqnx tree. They're part of the
   Harman-Becker SDK, which does not ship publicly. Two paths:
   - Reverse the `.so` files' exported symbol tables and reconstruct
     headers from mangled C++ signatures
   - Clone from the Java-side `org.dsi.ifc.persistence.DSIPersistence`
     interface (which we *do* have from extracted `dsi.jar` / `DSITracer.jar`)
     and write equivalent C++ stubs

3. **Connect to `servicebroker`.** Process #95 is the registry. A
   `CDSICtrl` instance is initialized first to bind to it, then
   individual service proxies register their interest in specific
   interface names.

4. **Attach to a service channel.** `CDSIChannel::Connect()` via
   QNX `ConnectAttach` gets you a file descriptor. From there it's
   standard `MsgSendv`-based RPC: marshal a RequestEvent, send,
   demarshal the ResponseEvent.

The service broker connects consumer to provider by name. Names
come from the `<InterfaceTable>` section of `mmi3g-srv-starter.cfg`
(105 interfaces total; grep for `CheckInterval` for each).

## Open questions

Things not yet resolved that would help future native work:

1. **Exact layout of `RequestEvent` messages on the wire.** Does DSI
   use a standard marshalling format (XDR? CORBA GIOP? something
   Harman-proprietary?) or does each service define its own format?
   Answer is in `libdsiservice.so` — somebody loading that in Ghidra
   and looking at the generic request-build code would find out in
   an afternoon.

2. **The 64-bit persistence key encoding.** Upper vs lower 32 bits
   split is obvious, but which subfields? Likely structure:
   `[namespace_id:8][table_id:8][reserved:16][address:32]` — could
   confirm by correlating keys we see in GEM ESD files against
   values we read.

3. **Listener registration path.** The Java side registers listeners
   via `addListener`/`removeListener` on `DSIPersistenceListener`.
   The C++ side must have an equivalent — there's a
   `CDSIAccessNotificationEvent` class but how clients subscribe to
   a specific key's updates is unclear from strings alone. Needed
   for per3-reader's "subscribe to changes" capability.

4. **The `selftest` entry.** A single string in MMI3GApplication
   says `"notification-id %d: starting selftest (all responses/
   notifications with sample values are sent)..."` — a built-in
   DSI self-test mode. If there's a config knob or GEM screen that
   triggers it, that would be a great way to exercise the whole
   DSI stack without the full HMI running. Worth grepping
   config files and GEM ESDs for this.

## References

- Extracted binary: `/usr/apps/MMI3GApplication` from K0942_4 variant 41
- Extracted libraries: `/usr/lib/libdsi*.so` (in IFS extraction)
- `openqnx/trunk/services/system/public/sys/` — QNX MsgSendv primitives
- `modules/per3-reader/src/stubs/` — Java equivalent of this API surface
