# Module completion hardening

A module that shows a status screen must **always advance the screen** and must
never wedge on a hung QNX utility. Issues #12 and #13 were exactly this: the
System Info module hung on `pidin fd` with no timeout and no completion trap, so
the unit sat on `running.png` ("Running Diagnose") forever.

The fix is a small set of shared helpers in [`core/platform.sh`](../core/platform.sh)
(sourced by every module). Use them in any module that shows `running.png`.

## Helpers

| Helper | Purpose |
|---|---|
| `mmi_show_screen <png>` | Best-effort, backgrounded `showScreen` of `lib/<png>` (uses `$SDPATH`). |
| `mmi_arm_completion [png]` | Guarantee the screen advances to `png` (default `done.png`) however the script exits — normal end, crash, or `INT`/`TERM`/`HUP`. Call once, right after showing `running.png`. |
| `mmi_run_bounded <secs> <cmd…>` | Run `<cmd>` under a hard time budget so a hang loses only that command. Redirect at the call site. |
| `mmi_at_exit '<cmd>'` | Register a cleanup on exit; composes (does not clobber) with other registrants (e.g. `mmi_reclaim_hold`). |

Budgets `MMI_CMD_BUDGET` (20s) and `MMI_RUN_BUDGET` (300s) are environment-overridable.

## Recipe

```sh
. "${SDPATH}/scripts/common/platform.sh"   # already done by every module

mmi_arm_completion done.png                # screen always advances off running.png
mmi_show_screen running.png

# … work … wrap any hang-prone dump (pidin/sloginfo/qdbc/…):
mmi_run_bounded "${MMI_CMD_BUDGET}" pidin ar > "${OUT}/processes.txt" 2>/dev/null

# Do NOT emit done.png at the end — the completion trap owns it.
```

## Status

- **Hardened:** `system-info` (PR #15, self-contained), and `google-earth`,
  `gemmi-dump`, `dns-refresh-probe`, `persistence-dump` (via the shared helpers).
- **Out of scope:** modules that do not show `running.png` can't get stuck on the
  screen; install/write modules that already use `trap … EXIT INT TERM` for
  rollback (`per3-*`, `nav-unblocker`, `lte-setup`, `splash-screen`, …) are a
  different concern and are left as-is.

Tests: `tests/test_platform_hardening.py` (the shared helpers) and
`tests/test_system_info_robustness.py`. CI runs them under dash and mksh.
