#!/bin/ksh
# ============================================================
# MMI3G-Toolkit — platform detection helper
# Source this from any module script:  . /scripts/common/platform.sh
# (or from SD:  . ${SDPATH}/scripts/common/platform.sh)
# ============================================================
#
# Provides these variables / functions to the sourcing script:
#
#   $MMI_VARIANT      "MMI3G_BASIC" | "MMI3G_HIGH" | "MMI3GP" | "RNS850" | "UNKNOWN"
#   $MMI_VARIANT_ID   "9304" | "9308" | "9411" | "9436" | "9478" | ""
#   $MMI_TRAIN        the train name string (e.g. "HN+R_EU_AU_K0942_4"), or "n/a"
#   $MMI_SW_VERSION   main unit software version string, or "n/a"
#   $MMI_HW_SAMPLE    /etc/hwSample contents, or "n/a"
#
# Known variant IDs:
#     9304  MMI 3G Basic
#     9308  MMI 3G High
#     9411  MMI 3G Plus (A4/A5/A6/A7/A8/Q5/Q7 etc)
#     9436  MMI 3G Plus, Audi A1 8X variant  (per DrGER2)
#     9478  MMI 3G Plus, RNS-850 / VW
#
#   mmi_getTime       wall-clock timestamp (seconds since epoch) —
#                     prefers Harman-Becker getTime over QNX date
#                     because `date` on a just-booted MMI returns
#                     elapsed-since-boot until the CAN gateway
#                     pushes a real time.
#   mmi_logstamp      YYYYMMDD-HHMMSS string suitable for filenames,
#                     using the same getTime-preferred source.
#
# Corrections from DrGER2 review (2026-04):
#   * /etc/pci-3g_XXXX.cfg is the authoritative variant identifier
#     on ALL three platforms (Basic/High/Plus). sw_trainname.txt
#     is only populated on 3G+.
#   * RNS-850 is identified by "_VW_" appearing in the train name
#     (e.g. HN+_US_VW_K0711), not by a literal "RNS" string.
#   * Use getTime not date for real wall-clock timestamps.

# ============================================================
# QNX Compatibility Shims
# ============================================================
# QNX 6.3 ships a minimal userland — many standard POSIX/GNU
# utilities are missing.  The functions below provide drop-in
# replacements that activate ONLY when the real command is absent.
# On Linux/macOS the native commands are used unchanged.
# ============================================================

# What a real unit has (probed on an A6 MMI 3G+, K0942_3, 2026-11-27):
#   sed grep cat ls cp mv rm mkdir cksum df netstat ifconfig pidin
#   sloginfo ping date uname use slay mount route touch chmod ln sleep
# and NOT: awk head tail cut tr sort uniq wc xargs find basename dirname
#   printf readlink (nor dd od strings diff md5 tee expr env gzip tar).
# The stand-ins below cover what the toolkit's scripts use, with the
# same file arguments the real tools take. tests/test_unit_tools.py
# checks every on-unit script against this list.

# head [-n N | -N] [file...]: sed quits after N lines, so a long pipe stops early
if ! command -v head >/dev/null 2>&1; then
    head() {
        local _n=10
        case "$1" in
            -n) _n="$2"; shift 2 ;;
            -n*) _n="${1#-n}"; shift ;;
            -c|-c*) echo "head: -c is not available on this unit" >&2; return 1 ;;
            -[0-9]*) _n="${1#-}"; shift ;;
        esac
        [ "$_n" -gt 0 ] 2>/dev/null || return 0
        sed "${_n}q" "$@"
    }
fi

# tail [-n N | -N] [file...]: keeps the last N lines in sed's hold space
if ! command -v tail >/dev/null 2>&1; then
    tail() {
        local _n=10
        case "$1" in
            -n) _n="$2"; shift 2 ;;
            -n*) _n="${1#-n}"; shift ;;
            -f|-c|-c*) echo "tail: $1 is not available on this unit" >&2; return 1 ;;
            -[0-9]*) _n="${1#-}"; shift ;;
        esac
        [ "$_n" -gt 0 ] 2>/dev/null || return 0
        if [ "$_n" -eq 1 ]; then
            sed -n '$p' "$@"
        else
            sed -e ':a' -e '$q' -e 'N' -e "$((_n + 1)),\$D" -e 'ba' "$@"
        fi
    }
fi

# basename path [suffix]
if ! command -v basename >/dev/null 2>&1; then
    basename() {
        local _p="${1%/}"
        _p="${_p##*/}"
        if [ -n "$2" ]; then
            _p="${_p%$2}"
        fi
        echo "$_p"
    }
fi

# dirname path
if ! command -v dirname >/dev/null 2>&1; then
    dirname() {
        local _d="${1%/}"
        case "$_d" in
            */*) _d="${_d%/*}"; echo "${_d:-/}" ;;
            '') echo "/" ;;
            *) echo "." ;;
        esac
    }
fi

# wc -l [file]: count lines with a read loop
if ! command -v wc >/dev/null 2>&1; then
    wc() {
        if [ "$1" != "-l" ]; then
            echo "wc: only -l is available on this unit" >&2; return 1
        fi
        shift
        local _c=0
        if [ -n "$1" ]; then
            while IFS= read -r _; do _c=$((_c + 1)); done < "$1"
            echo "      $_c $1"
        else
            while IFS= read -r _; do _c=$((_c + 1)); done
            echo "$_c"
        fi
    }
fi

# printf: echo for the simple cases (%s / %d with their arguments)
if ! command -v printf >/dev/null 2>&1; then
    printf() {
        local _fmt="$1"; shift
        case "$_fmt" in
            *%s*|*%d*) echo "$@" ;;
            *)    echo "$_fmt" "$@" ;;
        esac
    }
fi

# awk [-F sep] '{print $N}' [file...]: one field per line, the only program the toolkit uses
if ! command -v awk >/dev/null 2>&1; then
    awk() {
        local _sep="" _prog _field
        case "$1" in
            -F) _sep="$2"; shift 2 ;;
            -F*) _sep="${1#-F}"; shift ;;
        esac
        _prog="$1"; shift
        _field="${_prog#\{print \$}"; _field="${_field%\}}"
        case "$_field" in
            ''|*[!0-9]*)
                echo "awk: only '{print \$N}' is available on this unit" >&2
                return 1 ;;
        esac
        cat "$@" | (
            set -f
            [ -n "$_sep" ] && IFS="$_sep"
            while read -r _line; do
                set -- $_line
                eval "echo \"\${$_field}\""
            done
        )
    }
fi

# cut -d X -f N | -f N- | -c A-B [file...]: sed does the work
if ! command -v cut >/dev/null 2>&1; then
    cut() {
        local _d="	" _f="" _c="" _a _b _q _r
        while [ $# -gt 0 ]; do
            case "$1" in
                -d) _d="$2"; shift 2 ;;
                -d*) _d="${1#-d}"; shift ;;
                -f) _f="$2"; shift 2 ;;
                -f*) _f="${1#-f}"; shift ;;
                -c) _c="$2"; shift 2 ;;
                -c*) _c="${1#-c}"; shift ;;
                *) break ;;
            esac
        done
        if [ -n "$_c" ]; then
            _a="${_c%%-*}"; _b="${_c#*-}"
            [ "$_c" = "$_a" ] && _b="$_a"
            [ -z "$_a" ] && _a=1
            if [ -z "$_b" ]; then
                sed "s/^.\{$((_a - 1))\}//" "$@"
            else
                sed -e "s/^.\{$((_a - 1))\}//" -e "s/^\(.\{0,$((_b - _a + 1))\}\).*/\1/" "$@"
            fi
            return
        fi
        case "$_f" in
            ''|*,*) echo "cut: only -f N, -f N- and -c A-B are available on this unit" >&2; return 1 ;;
        esac
        # the delimiter inside a bracket expression; ']' '^' '\' are not supported
        _q="[$_d]"; _r="[^$_d]"
        case "$_f" in
            *-) _a="${_f%-}"
                sed -e "/$_q/!b" -e "s/^\($_r*$_q\)\{$((_a - 1))\}//" -e 't' -e 's/.*//' "$@" ;;
            *)  _a="$_f"
                sed -e "/$_q/!b" -e "s/^\($_r*$_q\)\{$((_a - 1))\}\($_r*\).*/\2/" -e 't' -e 's/.*//' "$@" ;;
        esac
    }
fi

# tr -d SET | tr SET1 SET2 (ranges a-z A-Z 0-9 A-F a-f, and \r \n \t)
if ! command -v tr >/dev/null 2>&1; then
    _tr_set() {
        echo "$1" | sed -e 's/a-z/abcdefghijklmnopqrstuvwxyz/g' -e 's/A-Z/ABCDEFGHIJKLMNOPQRSTUVWXYZ/g' \
            -e 's/a-f/abcdef/g' -e 's/A-F/ABCDEF/g' -e 's/0-9/0123456789/g'
    }
    tr() {
        local _s1 _s2 _cr _tab
        _cr="$(echo x | sed 's/x/\r/')"
        _tab="$(echo x | sed 's/x/\t/')"
        if [ "$1" = "-d" ]; then
            case "$2" in
                '\r') sed "s/$_cr//g" ;;
                '\n') echo "tr: -d '\\n' is not available on this unit" >&2; cat; return 1 ;;
                '\t') sed "s/$_tab//g" ;;
                *) _s1="$(_tr_set "$2")"; sed "s/[$_s1]//g" ;;
            esac
            return
        fi
        _s1="$(_tr_set "$1")"; _s2="$(_tr_set "$2")"
        sed "y/$_s1/$_s2/"
    }
fi

# xargs [cmd args...]: runs cmd once per input line (file names with spaces stay whole)
if ! command -v xargs >/dev/null 2>&1; then
    xargs() {
        local _l
        [ $# -eq 0 ] && set -- echo
        while IFS= read -r _l; do
            [ -n "$_l" ] && "$@" "$_l"
        done
    }
fi

# find dir... [-maxdepth N] [-xdev] [-type f|d] [-name PATTERN]: a walk with
# shell globs. -xdev matters on the unit: /mnt/efs-persist has the owner's
# manual disc image (hundreds of MB, on the hard disk) mounted inside it.
if ! command -v find >/dev/null 2>&1; then
    _find_emit() {
        case "$_find_type" in
            f) [ -f "$1" ] || return 0 ;;
            d) [ -d "$1" ] || return 0 ;;
        esac
        if [ -n "$_find_name" ]; then
            case "${1##*/}" in
                $_find_name) ;;
                *) return 0 ;;
            esac
        fi
        echo "$1"
    }
    _find_walk() {
        local _e
        for _e in "$1"/* "$1"/.[!.]*; do
            [ -e "$_e" ] || [ -h "$_e" ] || continue
            _find_emit "$_e"
            if [ -d "$_e" ] && [ ! -h "$_e" ]; then
                # -xdev: a directory something else is mounted on is not walked
                case "$_find_mnts" in *"
$_e
"*) continue ;; esac
                if [ -z "$_find_max" ] || [ "$2" -lt "$_find_max" ]; then
                    _find_walk "$_e" $(($2 + 1))
                fi
            fi
        done
    }
    find() {
        local _dirs="" _d
        _find_type=""; _find_name=""; _find_max=""; _find_mnts=""
        while [ $# -gt 0 ]; do
            case "$1" in
                -maxdepth) _find_max="$2"; shift 2 ;;
                -xdev) _find_mnts="
$(mount 2>/dev/null | sed -n 's/^.* on \([^ ]*\) type .*$/\1/p')
"; shift ;;
                -type) _find_type="$2"; shift 2 ;;
                -name) _find_name="$2"; shift 2 ;;
                -print) shift ;;
                -*) echo "find: $1 is not available on this unit" >&2; return 1 ;;
                *) _dirs="$_dirs
$1"; shift ;;
            esac
        done
        [ -z "$_dirs" ] && _dirs="."
        echo "$_dirs" | while IFS= read -r _d; do
            [ -z "$_d" ] && continue
            [ -e "$_d" ] || { echo "find: $_d: No such file or directory" >&2; continue; }
            _find_emit "$_d"
            if [ -d "$_d" ] && [ "${_find_max:-1}" -gt 0 ]; then
                _find_walk "${_d%/}" 1
            fi
        done
    }
fi

# sort / sort -u: no sorting on the unit; -u drops repeated lines (keeps the first)
if ! command -v sort >/dev/null 2>&1; then
    sort() {
        local _u="" _l _seen
        [ "$1" = "-u" ] && { _u=1; shift; }
        if [ -z "$_u" ]; then
            cat "$@"; return
        fi
        _seen="
"
        cat "$@" | while IFS= read -r _l; do
            case "$_seen" in
                *"
$_l
"*) ;;
                *) echo "$_l"; _seen="$_seen$_l
" ;;
            esac
        done
    }
fi

# uniq: drops a line equal to the one before it
if ! command -v uniq >/dev/null 2>&1; then
    uniq() {
        local _l _prev="" _first=1
        cat "$@" | while IFS= read -r _l; do
            if [ -n "$_first" ] || [ "$_l" != "$_prev" ]; then
                echo "$_l"
            fi
            _prev="$_l"; _first=""
        done
    }
fi

# sync — QNX may not have sync; no-op if missing
if ! command -v sync >/dev/null 2>&1; then
    sync() { :; }
fi

# mkdir -p — QNX mkdir exists but -p may not create nested dirs
# Override with a function that creates each path component
_qnx_mkdir_p() {
    # Create each path component one at a time
    # Avoids QNX's "Function not implemented" error with mkdir -p
    local _d="$1"
    local _built=""
    # Handle absolute paths
    case "$_d" in /*) _built="/" ;; esac
    # Save and change IFS to split on /
    local _oldIFS="$IFS"
    IFS="/"
    set -- $_d
    IFS="$_oldIFS"
    for _seg in "$@"; do
        [ -z "$_seg" ] && continue
        _built="${_built}${_seg}"
        [ -d "$_built" ] || mkdir "$_built" 2>/dev/null
        _built="${_built}/"
    done
}

# Override mkdir to handle -p flag on QNX
# Test if mkdir -p actually works; only override if it fails
if ! mkdir -p /tmp/_mmi_test_mkdir_p 2>/dev/null; then
    _real_mkdir=$(command -v mkdir)
    mkdir() {
        if [ "$1" = "-p" ]; then
            shift
            for _d in "$@"; do
                _qnx_mkdir_p "$_d"
            done
        else
            $_real_mkdir "$@"
        fi
    }
else
    rmdir /tmp/_mmi_test_mkdir_p 2>/dev/null
fi

# readlink — QNX 6.3.2 has no readlink; return the path as-is
# or resolve symlinks manually with ls -la
if ! command -v readlink >/dev/null 2>&1; then
    readlink() {
        case "$1" in
            -f) shift
                # Best effort: resolve symlink via ls -la
                _target="$1"
                _link="$(ls -la "$_target" 2>/dev/null | sed -n 's/.* -> //p')"
                if [ -n "$_link" ]; then
                    echo "$_link"
                else
                    echo "$_target"
                fi
                ;;
            *)  # Simple readlink — just check symlink target
                _link="$(ls -la "$1" 2>/dev/null | sed -n 's/.* -> //p')"
                if [ -n "$_link" ]; then
                    echo "$_link"
                else
                    echo "$1"
                fi
                ;;
        esac
    }
fi

# ============================================================

# -------- Variant detection (authoritative: /etc/pci-3g_*.cfg) --------
MMI_VARIANT="UNKNOWN"
MMI_VARIANT_ID=""
if [ -f /etc/pci-3g_9304.cfg ]; then
    MMI_VARIANT="MMI3G_BASIC"
    MMI_VARIANT_ID="9304"
elif [ -f /etc/pci-3g_9308.cfg ]; then
    MMI_VARIANT="MMI3G_HIGH"
    MMI_VARIANT_ID="9308"
elif [ -f /etc/pci-3g_9411.cfg ]; then
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9411"
elif [ -f /etc/pci-3g_9436.cfg ]; then
    # DrGER2 2026-04: Audi A1 8X uses a distinct variant ID.
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9436"
elif [ -f /etc/pci-3g_9478.cfg ]; then
    MMI_VARIANT="MMI3GP"
    MMI_VARIANT_ID="9478"
else
    # Fallback if the pci-3g_*.cfg pattern is missing for some reason —
    # try globbing. New variant IDs can be slotted into the case below.
    for f in /etc/pci-3g_*.cfg; do
        [ -f "$f" ] || continue
        MMI_VARIANT_ID="$(echo "$f" | sed -n 's,^/etc/pci-3g_\([0-9]*\)\.cfg$,\1,p')"
        case "$MMI_VARIANT_ID" in
            9304)           MMI_VARIANT="MMI3G_BASIC" ;;
            9308)           MMI_VARIANT="MMI3G_HIGH" ;;
            9411|9436|9478) MMI_VARIANT="MMI3GP" ;;
            *)              MMI_VARIANT="UNKNOWN" ;;
        esac
        break
    done
fi

# -------- Train name (3G+ only populates sw_trainname.txt) --------
MMI_TRAIN="n/a"
if [ -f /dev/shmem/sw_trainname.txt ]; then
    _mmi_t="$(cat /dev/shmem/sw_trainname.txt 2>/dev/null)"
    [ -n "$_mmi_t" ] && MMI_TRAIN="$_mmi_t"
fi
# Basic/High fallback — DrGER2's sloginfo method
if [ "$MMI_TRAIN" = "n/a" ]; then
    _mmi_t="$(sloginfo -m 10000 -s 5 2>/dev/null | sed -n 's/^.* +++ Train //p' | sed -n 1p)"
    [ -n "$_mmi_t" ] && MMI_TRAIN="$_mmi_t"
fi

# -------- RNS-850 disambiguation --------
# RNS-850 has the "_VW_" infix (e.g. HN+_US_VW_K0711).
# A 9411 unit without _VW_ is a regular A4/A5/A6/A7/A8/Q5/Q7 MMI 3G+;
# 9436 is the A1 8X variant (smaller/cheaper hardware, same MMI 3G+ class);
# 9478 is the VW RNS-850 variant.
if [ "$MMI_VARIANT" = "MMI3GP" ] && echo "$MMI_TRAIN" | grep -q "_VW_"; then
    MMI_VARIANT="RNS850"
fi

# -------- Other identification sources --------
MMI_SW_VERSION="n/a"
if [ -f /etc/version/MainUnit-version.txt ]; then
    _mmi_v="$(sed -n 's/^version = //p' /etc/version/MainUnit-version.txt 2>/dev/null | head -1)"
    [ -n "$_mmi_v" ] && MMI_SW_VERSION="$_mmi_v"
fi

MMI_HW_SAMPLE="n/a"
if [ -f /etc/hwSample ]; then
    H="$(cat /etc/hwSample 2>/dev/null)"
    [ -n "$H" ] && MMI_HW_SAMPLE="$H"
fi

# -------- Time helpers --------
# DrGER2: QNX `date` returns time-since-boot until the CAN gateway
# delivers wall-clock. `getTime` (Harman-Becker binary) returns the
# real current time provided by the vehicle.
mmi_getTime() {
    if command -v getTime >/dev/null 2>&1; then
        getTime 2>/dev/null
    else
        date +%s 2>/dev/null
    fi
}

# Filename-safe timestamp. Uses getTime when available, falling back
# to date-formatted output. Format is always YYYYMMDD-HHMMSS so log
# filenames sort correctly regardless of source.
mmi_logstamp() {
    # Prefer getTime (epoch seconds) and format with date -r if possible
    if command -v getTime >/dev/null 2>&1; then
        _mmi_t="$(getTime 2>/dev/null)"
        if [ -n "$_mmi_t" ]; then
            # Try date -r (BSD/QNX) to format the epoch value
            if date -r "$_mmi_t" +%Y%m%d-%H%M%S 2>/dev/null; then
                return 0
            fi
            # Last resort: emit the raw epoch seconds (still uniquely sortable)
            echo "epoch-$_mmi_t"
            return 0
        fi
    fi
    # Fall through: QNX date (may be since-boot on a cold MMI)
    date +%Y%m%d-%H%M%S 2>/dev/null
}

# Reclaim interlock helpers. mmi3g-flashctl runs F3S garbage collection
# every 5 min against /HBpersistence; the /tmp/disableReclaim flag file
# blocks it. Toolkit scripts that do multi-write operations against
# /HBpersistence or /mnt/efs-system should call mmi_reclaim_hold at the
# start of their critical section and rely on the EXIT trap to release
# it. See research/F3S_FORMAT.md for details.
#
# Usage:
#   mmi_reclaim_hold          # set flag + install trap
#   ... critical writes ...
#   mmi_reclaim_release       # optional early release before exit
#
# The trap handles the normal exit path, Ctrl-C, and SIGTERM. If a
# script forgets to call release explicitly, the flag is still cleared
# on script exit.
mmi_reclaim_hold() {
    touch /tmp/disableReclaim 2>/dev/null
    mmi_at_exit 'rm -f /tmp/disableReclaim 2>/dev/null'
}

mmi_reclaim_release() {
    rm -f /tmp/disableReclaim 2>/dev/null
}

# ============================================================
# Module completion + timeout hardening (issues #12 / #13).
# A module that shows running.png must ALWAYS advance the screen
# (to done.png) however it exits, and a hung QNX utility must never
# wedge it. See docs/MODULE_HARDENING.md.
# ============================================================

# Per-heavy-command and whole-run time budgets (seconds). Overridable
# by the environment; defaults are generous for a healthy unit.
: "${MMI_CMD_BUDGET:=20}"
: "${MMI_RUN_BUDGET:=300}"

# Shared exit dispatch: helpers register cleanups here instead of each
# calling `trap` (which would clobber the others). INT/TERM/HUP re-exit
# so the EXIT handler still runs on a signal/reap.
_MMI_ON_EXIT=""
_mmi_run_exit() { eval "${_MMI_ON_EXIT}"; }
mmi_at_exit() {
    if [ -z "${_MMI_ON_EXIT}" ]; then
        _MMI_ON_EXIT="$1"
        trap _mmi_run_exit EXIT
        trap 'exit' INT TERM HUP
    else
        _MMI_ON_EXIT="${_MMI_ON_EXIT}; $1"
    fi
}

# Show a status PNG on the MMI screen (best-effort, backgrounded).
# $1 = basename under lib/ (running.png, done.png). Uses $SDPATH.
mmi_show_screen() {
    if [ -x "${SDPATH}/bin/showScreen" ] && [ -f "${SDPATH}/lib/$1" ]; then
        "${SDPATH}/bin/showScreen" "${SDPATH}/lib/$1" 2>/dev/null &
    fi
}

# Guarantee the screen advances to $1 (default done.png) however the
# script exits (normal end, crash, signal/reap) — the keystone fix for
# the "stuck on running.png" hang. Call once, right after showing
# running.png; do NOT also emit done.png at the end (the trap owns it).
mmi_arm_completion() {
    _mmi_done_png="${1:-done.png}"
    mmi_at_exit "mmi_show_screen \"${_mmi_done_png}\""
}

# Run a command under a hard time budget so a hung utility cannot wedge
# the module: a hang loses only that command. Redirect at the call site
# (`mmi_run_bounded N cmd > file 2>/dev/null`); the command inherits this
# function's stdout/stderr. The watchdog is /dev/null-redirected so an
# orphaned sleep can never hold a captured stdout pipe open.
mmi_run_bounded() {
    _rb_budget="$1"; shift
    "$@" &
    _rb_pid=$!
    ( sleep "${_rb_budget}"; kill -15 "${_rb_pid}" 2>/dev/null
      sleep 2; kill -9 "${_rb_pid}" 2>/dev/null ) >/dev/null 2>&1 &
    _rb_wd=$!
    wait "${_rb_pid}" 2>/dev/null
    _rb_rc=$?
    kill -9 "${_rb_wd}" 2>/dev/null
    wait "${_rb_wd}" 2>/dev/null
    return ${_rb_rc}
}

