#!/bin/ksh
# ============================================================
# Coding Changelog — compare recent coding snapshots on SD
# Runs from GEM button, reports diffs between last N dumps
# ============================================================

SDPATH="${1:-/fs/sda1}"
for sd in /fs/sda1 /fs/sda0 /fs/sd1 /fs/sd0; do
    if [ -d "$sd" ]; then
        SDPATH=$sd
        break
    fi
done

CODINGDIR="${SDPATH}/var/coding"
if [ ! -d "$CODINGDIR" ]; then
    echo "No coding dumps found at $CODINGDIR."
    echo "Run 'Dump ALL codings to SD' first, make your changes,"
    echo "then run this to see what moved."
    exit 0
fi

# Find last 10 coding dump files
FILES=$(ls -1t ${CODINGDIR}/coding-*.txt 2>/dev/null | head -10)
if [ -z "$FILES" ]; then
    echo "No coding-*.txt dumps found in $CODINGDIR."
    exit 0
fi

echo "=== Last 10 coding snapshots ==="
echo "$FILES"
echo ""

# Compare newest two
NEWEST=$(echo "$FILES" | head -1)
PREV=$(echo "$FILES" | head -2 | tail -1)

if [ "$NEWEST" = "$PREV" ] || [ -z "$PREV" ]; then
    echo "Only one snapshot exists. Take another (make a change first) and run again."
    exit 0
fi

echo ""
echo "=== Diff: $(basename $PREV) -> $(basename $NEWEST) ==="
diff "$PREV" "$NEWEST" | head -100
echo ""
echo "(showing first 100 diff lines — full diff in SD card logs)"

# Save full diff
DIFF_OUT="${CODINGDIR}/changelog-$(date +%Y%m%d-%H%M%S).diff"
diff "$PREV" "$NEWEST" > "$DIFF_OUT" 2>&1
echo "Full diff saved to: $DIFF_OUT"
sync
