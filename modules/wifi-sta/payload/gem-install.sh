#!/bin/ksh
# Phases 7.4a to 7.6: install, inspect or remove the Wi-Fi client's
# engineering (GEM) screen on this unit (9411, HN+R_US_AU_K0942_3). See
# docs/wifi-client/wifi-client-mode.md, "The GEM screen (7.4a), prepared
# offline", "The start button and persistent files (7.4b, 7.5)" and
# "Station mode at start-up (7.6)".
#
#   status           what is installed, where the GEM reads its definitions,
#                    free space
#   install <dir>    from a directory holding WifiClient.esd and gem.sh (each
#                    checked against the sums below): gem.sh and its
#                    "status", "client", "ap", "start" and "check" links
#                    into /mnt/efs-persist/wifi-sta/gem,
#                    then WifiClient.esd into the factory definition
#                    directory /mnt/efs-system/engdefs, which the GEM reads
#                    through /HBpersistence/engdefs
#   remove           take all of it out again, this build's or an older
#                    one's; gem.log goes to /fs/tmpfs. The start-up marker
#                    goes too: without the screen, nothing could switch the
#                    access point back.
#
# Nothing factory is changed: the screen is one added file and the scripts
# run only when a button is pressed. An older build is replaced by remove,
# then install. The GEM reads its definitions when the
# HMI starts, so a change shows only after a restart. A dropped SSH session
# (HUP) does not stop it. Exit: 0 done, 1 usage, 2 refused or failed.
set -u
umask 022
PATH=/bin:/sbin:/usr/bin:/usr/sbin
export PATH
unset LD_PRELOAD || :

efs=/mnt/efs-system
persist=/mnt/efs-persist
engdefs=$efs/engdefs
# efs_symlinks.cfg links this to $engdefs at every start-up; lsd.sh points
# the GEM (de.audi.tghu.engineering.base_dir) here.
gem_dir_link=/HBpersistence/engdefs
esd_name=WifiClient.esd
esd=$engdefs/$esd_name
top=$persist/wifi-sta
dir=$top/gem
links='status client ap start check'
esd_sum='563898311 762'
gem_sum='201203542 12514'
# Earlier builds that remove also takes out: 7.4a (status and check only)
# and 7.4b (and start).
esd_older='2799610818 405,3567683713 529'
gem_older='1675214043 5649,3629712146 10439'
# gem.sh start-up marker (sta-boot.sh).
marker=$dir/client-at-start-up
# RAM: gone after a restart.
run=/fs/tmpfs
lock=$run/wifi-gem.lock
min_free_kb=64
locked=no
txn=none

usage() {
    echo "usage: gem-install.sh status | install <dir> | remove" >&2
    exit 1
}

say() {
    echo "wifi-gem: $*"
    [ -d "$dir" ] && ( echo "$(date) $*" >> "$dir/install.log" ) 2>/dev/null
    return 0
}

fail() {
    say "FAIL: $*"
    exit 2
}

sum_of() {
    cksum "$1" 2>/dev/null | { read -r a b rest && echo "$a $b"; }
}

free_kb() {
    df -k "$1/" 2>/dev/null | grep '^/dev/' | sed -n 1p |
        { read -r fs total used avail rest && echo "$avail"; }
}

writable() {
    probe=$1/.wifi-gem-probe.$$
    if ( : > "$probe" ) 2>/dev/null; then
        rm -f "$probe"
        return 0
    fi
    return 1
}

# The GEM's directory has to be the factory one, through the start-up link.
link_ok() {
    ls -ld "$gem_dir_link" 2>/dev/null | grep -q -- "-> $engdefs\$"
}

count_esd() {
    n=$(ls "$engdefs" 2>/dev/null | grep '\.esd$' | sed -n '$=')
    echo "${n:-0}"
}

take_lock() {
    if ! mkdir "$lock" 2>/dev/null; then
        holder=$(cat "$lock/pid" 2>/dev/null)
        if [ -n "$holder" ] && kill -0 "$holder" 2>/dev/null; then
            fail "another gem-install.sh (pid $holder) holds $lock"
        fi
        say "removing a stale lock (pid ${holder:-unknown})"
        rm -rf "$lock"
        mkdir "$lock" 2>/dev/null || fail "cannot take $lock"
    fi
    locked=yes
    echo $$ > "$lock/pid"
}

# put <source> <target> <mode> <expected sum>: copy beside the target,
# check it, then rename it into place and check again.
put() {
    put_new=$2.new.$$
    rm -f "$put_new"
    cp "$1" "$put_new" 2>/dev/null || { rm -f "$put_new"; return 1; }
    chmod "$3" "$put_new" || { rm -f "$put_new"; return 1; }
    if [ "$(sum_of "$put_new")" != "$4" ]; then
        rm -f "$put_new"
        return 1
    fi
    mv -f "$put_new" "$2" || { rm -f "$put_new"; return 1; }
    [ "$(sum_of "$2")" = "$4" ]
}

# A link named $1 in $dir that points at gem.sh.
link_is_ours() {
    [ -L "$dir/$1" ] && ls -l "$dir/$1" 2>/dev/null | grep -q -- '-> gem.sh$'
}

# One letter: a absent, i this build, o an older build (its sums are
# separated by commas), x anything else.
build_of() {
    [ -f "$1" ] || { echo a; return 0; }
    bo_sum=$(sum_of "$1")
    if [ "$bo_sum" = "$2" ]; then echo i; return 0; fi
    case ",$3," in
        *",$bo_sum,"*) echo o ;;
        *) echo x ;;
    esac
}

state_of() {
    s=$(build_of "$esd" "$esd_sum" "$esd_older")$(build_of "$dir/gem.sh" "$gem_sum" "$gem_older")
    for l in $links; do
        if [ ! -e "$dir/$l" ] && [ ! -L "$dir/$l" ]; then s=${s}a
        elif link_is_ours "$l"; then s=${s}i
        else s=${s}x; fi
    done
    case $s in
        *x*) echo other ;;
        *[!a]*) case $s in
                    *[!i]*) case $s in *o*) echo older ;; *) echo partial ;; esac ;;
                    *) echo installed ;;
                esac ;;
        *) echo absent ;;
    esac
}

remove_ours() {
    remove_rc=0
    # The definition first: without it the screen does not appear.
    if [ -f "$esd" ]; then
        if [ "$(build_of "$esd" "$esd_sum" "$esd_older")" != x ]; then
            rm -f "$esd"
            [ -f "$esd" ] && { say "could not remove $esd"; remove_rc=1; }
        else
            say "$esd is not this build's ($(sum_of "$esd")); left in place"
            remove_rc=1
        fi
    fi
    for l in $links; do
        if link_is_ours "$l"; then
            rm -f "$dir/$l"
        elif [ -e "$dir/$l" ] || [ -L "$dir/$l" ]; then
            say "$dir/$l is not a link to gem.sh; left in place"
            remove_rc=1
        fi
    done
    rm -f "$marker"
    if [ -f "$dir/gem.sh" ]; then
        if [ "$(build_of "$dir/gem.sh" "$gem_sum" "$gem_older")" != x ]; then
            rm -f "$dir/gem.sh"
        else
            say "$dir/gem.sh is not this build's; left in place"
            remove_rc=1
        fi
    fi
    return "$remove_rc"
}

finish() {
    finish_rc=$?
    trap '' 1 2 15
    if [ "$txn" = active ]; then
        txn=none
        say "undoing the partial install"
        remove_ours || { say "FAIL: the partial install was not fully undone"; finish_rc=2; }
    fi
    rm -f "$engdefs"/*.new.$$ "$dir"/*.new.$$ 2>/dev/null
    [ "$locked" = yes ] && rm -rf "$lock"
    exit "$finish_rc"
}

status() {
    say "state: $(state_of)"
    if link_ok; then
        say "$gem_dir_link -> $engdefs, $(count_esd) definitions"
    else
        say "$gem_dir_link: $(ls -ld "$gem_dir_link" 2>&1)"
    fi
    if [ -f "$esd" ]; then say "$esd: $(sum_of "$esd") (this build $esd_sum)"; else say "$esd: absent"; fi
    if [ -d "$dir" ]; then
        if [ -f "$dir/gem.sh" ]; then
            say "$dir/gem.sh: $(sum_of "$dir/gem.sh") (this build $gem_sum)"
        else
            say "$dir/gem.sh: absent"
        fi
        for l in $links; do
            say "$dir/$l: $(ls -l "$dir/$l" 2>&1 | sed -e 's/.* -> /-> /')"
        done
        if [ -f "$dir/gem.log" ]; then
            set -- $(ls -l "$dir/gem.log")
            say "$dir/gem.log: ${5:-?} bytes"
        fi
    else
        say "$dir: absent"
    fi
    for d in "$efs" "$persist"; do
        if writable "$d"; then say "$d: writable, $(free_kb "$d") KB free"; else say "$d: READ-ONLY"; fi
    done
}

install() {
    stage=$1
    [ -d "$stage" ] || fail "$stage is not a directory"
    [ "$(sum_of "$stage/$esd_name")" = "$esd_sum" ] ||
        fail "$stage/$esd_name is not this build's ($esd_sum): $(sum_of "$stage/$esd_name")"
    [ "$(sum_of "$stage/gem.sh")" = "$gem_sum" ] ||
        fail "$stage/gem.sh is not this build's ($gem_sum): $(sum_of "$stage/gem.sh")"
    take_lock
    state=$(state_of)
    case $state in
        absent) ;;
        installed) say "already installed from this build"; return 0 ;;
        older) fail "an older build is installed; run remove first, then install" ;;
        *) fail "the files are $state, not absent; remove them first" ;;
    esac
    link_ok || fail "$gem_dir_link does not lead to $engdefs: $(ls -ld "$gem_dir_link" 2>&1)"
    # The screen name must be new: the GEM keeps one screen per name.
    others=$(grep -i -l 'wificlient' "$engdefs"/*.esd 2>/dev/null)
    [ -z "$others" ] || fail "a definition already names WifiClient: $others"
    for d in "$efs" "$persist"; do
        writable "$d" || fail "$d is read-only; this script does not remount it"
        free=$(free_kb "$d")
        case $free in
            ''|*[!0-9]*) fail "cannot read the free space of $d" ;;
        esac
        [ "$free" -ge "$min_free_kb" ] || fail "$d has only ${free} KB free, needs $min_free_kb"
    done
    before=$(count_esd)
    # One level at a time: the unit's mkdir -p fails on the /mnt prefix.
    for d in "$top" "$dir"; do
        [ -d "$d" ] || mkdir "$d" 2>/dev/null
    done
    [ -d "$dir" ] || fail "cannot create $dir"
    say "install from $stage; $before definitions in $engdefs"
    txn=active
    put "$stage/gem.sh" "$dir/gem.sh" 755 "$gem_sum" || fail "could not install gem.sh"
    for l in $links; do
        ln -s gem.sh "$dir/$l" 2>/dev/null || fail "could not link $dir/$l"
    done
    # The GEM runs the file itself, not through ksh, and a failed exec only
    # reaches J9's stderr. Run it the same way once; under its own name it
    # only reports that name.
    ran=$("$dir/gem.sh" 2>&1)
    case $ran in
        *'unknown action gem.sh'*) say "$dir/gem.sh runs directly" ;;
        *) fail "$dir/gem.sh does not run directly: $ran" ;;
    esac
    # The definition last: it is what makes the screen appear.
    put "$stage/$esd_name" "$esd" 644 "$esd_sum" || fail "could not install $esd"
    [ "$(state_of)" = installed ] || fail "the files are not as installed"
    txn=none
    say "installed: $esd ($esd_sum), $dir/gem.sh ($gem_sum) and its links; $(count_esd) definitions (was $before). Restart the unit for the GEM to read it."
}

remove() {
    take_lock
    state=$(state_of)
    if [ "$state" = absent ]; then
        say "nothing is installed"
    else
        writable "$efs" || fail "$efs is read-only; this script does not remount it"
        remove_ours || fail "removal incomplete (state $(state_of))"
        [ "$(state_of)" = absent ] || fail "removal left $(state_of) files"
        say "removed (was $state). The screen stays until the next restart; its buttons then report \"Script not found!\"."
    fi
    if [ -d "$dir" ]; then
        for f in gem.log gem.log.old install.log; do
            [ -f "$dir/$f" ] && mv -f "$dir/$f" "$run/wifi-gem.$f" 2>/dev/null
        done
        rmdir "$dir" 2>/dev/null || say "$dir is not empty; left in place"
    fi
    [ -d "$top" ] && rmdir "$top" 2>/dev/null
    [ -f "$run/wifi-gem.gem.log" ] && echo "wifi-gem: the logs are in $run/wifi-gem.* until the restart"
    return 0
}

trap finish 0
# A dropped SSH session must not stop a copy halfway; an interrupt or a
# kill undoes it.
trap '' 1
trap 'say "interrupted"; exit 2' 2 15
[ $# -ge 1 ] || usage
case $1 in
    status) [ $# = 1 ] || usage; status ;;
    install) [ $# = 2 ] || usage; install "$2" ;;
    remove) [ $# = 1 ] || usage; remove ;;
    *) usage ;;
esac
