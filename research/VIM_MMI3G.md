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
| 3 | Feed that serial to a VIM code generator to produce the **Security Access login code** |
| 4 | **Security Access – 16** → enter the generated code |
| 5 | **Adaptation – 10** → channel **48** → read current, set to **255**, test, save |
| 6 | Reset the MMI (**Setup + scroll-wheel + top-right menu** buttons, held together) |

Notes:
- The generator typically yields two codes; **if the second is rejected, that
  train/module simply doesn't support VIM adaptation.**
- **MMI 2G is different** — module **07**, channel **63** (out of scope here).
- Always read the current value before writing; the change is fully reversible
  in VCDS/ODIS.

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

Two things make this worth pursuing for VIM specifically:

1. **It may sidestep Security Access.** SA-16 gates the *diagnostic* (UDS `0x27`)
   write path that VCDS uses. An internal persistence write goes IOC-side, not
   through a UDS session — so it may set channel 48 **without** the serial→code
   login dance. Hypothesis, needs testing.
2. **The address just needs mapping.** Method:
   ```
   per3_dump.sh 3            # dump namespace 3 before
   # ... enable VIM once via VCDS (5F, adaptation 48 = 255) ...
   per3_dump.sh 3            # dump after
   diff before after        # the changed key = VIM's persistence address
   ```
   That delta is the missing piece to wire VIM into per3-writer as a one-file SD
   toggle. If you map it, please drop it on issue #10.

## Legal / safety

Driver-visible video while moving is **legally restricted in many regions** for
distraction/road-safety reasons. Treat this as bench/testing, enable at your own
risk, and know it's reversible via VCDS/ODIS.

## Sources

- bestcarmods.com/vim/ — MMI 3G VIM via VCDS (5F, SA-16, adaptation 48 = 255)
- audienthusiasts.com/Articles_VIM.html — step-by-step 5F / Advanced-ID serial →
  Security Access → adaptation channel 48, with the legal caveat
- Community reference for the coding location; toolkit specifics from this repo's
  `modules/` and [GEM_COMPLETE_MAP.md](GEM_COMPLETE_MAP.md).
