# VIM (Video In Motion) on MMI 3G

**TL;DR — VIM is not a firmware mod. It's a VCDS *adaptation* on the MMI head
unit (control module 5F), gated by a serial-derived Security Access login.** The
toolkit can get you engineering access and *read* the value, but the write today
is a VCDS/ODIS job. An SD-card automation path exists on paper (see
[per3-writer](../modules/per3-writer/)) but isn't implemented yet.

Raised in [issue #10](https://github.com/dspl1236/MMI3G-Toolkit/issues/10) — "Can
these scripts unlock VIM?". This note is the honest answer, on record.

## What VIM is

"Video In Motion" lifts the speed lock that blanks TV/AV/external video once the
car is moving. On MMI 3G it lives in the MMI's own coding — specifically an
**adaptation channel in control module 5F (Information Electronics / J794)** —
not in any flashable image. So there is nothing to patch, carve, or repack; it's
a single stored value behind a security gate.

## The VCDS procedure (the proven route)

| step | action |
|------|--------|
| 1 | Select control module **5F – Information Electronics** |
| 2 | **Advanced ID – 1A** → read the navigation unit **serial number** (first field if several) |
| 3 | Derive the **Security Access login** from that serial. Per the C7 community list it's the digits at positions **6, 13, 10, 14, 11** of the 1st serial (some trains instead need a serial→code generator/online decoder) |
| 4 | **Security Access – 16** (16 is the VCDS security-access *function*, not the code) → enter the derived login |
| 5 | **Adaptation – 10** → channel **48** → read current, set to **255**, test, save |
| 6 | Reset the MMI (**Menu + big knob + top-right soft button**, held together; some trains use Setup instead of Menu) |

Notes:
- Not every 5F train carries VIM — if the login or the channel-48 write is
  rejected, that unit doesn't support the adaptation.
- **MMI 2G is different** — module **07**, channel **63** (out of scope here).
- Always read the current value before writing; the change is fully reversible
  in VCDS/ODIS.

## MMI 3G vs 3G+ — why the codes may be rejected

The serial-digit Security Access derivation above (and the common online VIM
code generators) are for **MMI 3G non-plus** — the A6/A7 C7-era units. On
**MMI 3G+ (3GP)** Audi changed the Security Access algorithm, so those logins
are **rejected even when entered correctly** (reported on
[issue #10](https://github.com/dspl1236/MMI3G-Toolkit/issues/10) for a 2014
Audi Q3 3G+). It's the algorithm, not user error.

- 3G+ trains report internal variant IDs **9411 / 9436 / 9478** (vs 9304 = 3G
  basic, 9308 = 3G high — see the variant detection in
  [modules/long-coding](../modules/long-coding/) / [variant-dump](../modules/variant-dump/)).
- A 3G+ car needs a **3G+-specific** security code (a 3G+-aware calculator /
  ODIS / OBDeleven), or the non-VCDS internal-write route below.
- First confirm the unit even exposes 5F adaptation channel 48 — not every
  train carries the VIM adaptation.

## Where the toolkit fits today

- **[gem-activator](../modules/gem-activator/)** *(ready)* — opens the Green
  Engineering Menu from the SD card (`touch /HBpersistence/DBGModeActive`), no
  VCDS. This is engineering **access**, not the coding change.
- **[long-coding](../modules/long-coding/)** *(alpha, read-only)* — displays the
  current adaptation values inside the GEM, so you can confirm 5F / channel 48
  before and after a change. It deliberately does **not** write (see the module's
  own note: to change values, use VCDS 5F or ODIS).

So the current workflow is: **toolkit to get in and read, VCDS to write.**

## The automation lead (open research)

Channel 48 is stored in the MMI's **DSI persistence** (the same `per N 0xADDR`
store the GEM reads — see [GEM_COMPLETE_MAP.md](GEM_COMPLETE_MAP.md)). The
[per3-writer](../modules/per3-writer/) design aims to write those persistence
values straight from an SD card via `DSIPersistence.requestWriteInt`.

Helpfully, the **GEM hidden menu is itself a 5F adaptation — channel 6 = 1**
(per the C7 list), which is exactly the address `per3-writer`'s README already
sets out to map for GEM-enable. So channels **6** (hidden menu) and **48** (VIM)
are neighbouring 5F adaptations living in the same persistence namespace —
whatever dump-diff maps one will surface the other.

Two things make this worth pursuing for VIM specifically:

1. **It may sidestep Security Access.** SA-16 gates the *diagnostic* (UDS `0x27`)
   write path that VCDS uses. An internal persistence write goes IOC-side, not
   through a UDS session — so it may set channel 48 **without** the serial→code
   login dance. Hypothesis, needs testing.
2. **The address just needs mapping** — with the right tool. Adaptation
   keyValues live in the MMI's DSI (Java) persistence; read them with the
   [per3-reader](../modules/per3-reader/) OSGi bundle or the GEM coding screens,
   **not** a shell dump (`persistence-dump` only captures files — HBpersistence /
   efs-persist / shmem — which may not surface the value). Dump per3 namespace 3
   before and after a single **ch6 (GEM)** or **ch48 (VIM)** toggle, then diff —
   the changed key is the address. ch6 is the easiest first target, since
   `gem-activator` can toggle it with no VCDS. That delta wires the value into
   per3-writer; if you map it, please drop it on [issue #10](https://github.com/dspl1236/MMI3G-Toolkit/issues/10).

## Legal / safety

Driver-visible video while moving is **legally restricted in many regions** for
distraction/road-safety reasons. Treat this as bench/testing, enable at your own
risk, and know it's reversible via VCDS/ODIS.

## Sources

- bestcarmods.com/vim/ — MMI 3G VIM via VCDS (5F, SA-16, adaptation 48 = 255)
- audienthusiasts.com/Articles_VIM.html — step-by-step 5F / Advanced-ID serial →
  Security Access → adaptation channel 48, with the legal caveat
- audizine.com C7 A6/A7 & S6/S7 VAG-COM list — the serial-digit Security Access
  derivation (positions 6, 13, 10, 14, 11) and the `5F` `channel 6 = 1`
  hidden-menu enable (thread 566240)
- Toolkit specifics from this repo's `modules/` and
  [GEM_COMPLETE_MAP.md](GEM_COMPLETE_MAP.md).
