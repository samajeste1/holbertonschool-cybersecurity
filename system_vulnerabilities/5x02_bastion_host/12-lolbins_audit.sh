#!/bin/bash
# Audit Living off the Land Binaries (GTFOBins)

echo "=== Living off the Land Binaries Audit ==="
echo ""

echo "Checking GTFOBins candidates..."
echo ""

check_bin() {
    local path="$1"
    local warning="$2"
    if [ -f "$path" ]; then
        PERMS=$(ls -la "$path" | awk '{print $1}')
        if echo "$PERMS" | grep -q 's'; then
            echo "  $path: $PERMS (CRITICAL: SUID/SGID set!)"
        elif [ -n "$warning" ]; then
            echo "  $path: $PERMS ($warning)"
        else
            echo "  $path: $PERMS (OK)"
        fi
    fi
}

echo "File Readers (can read sensitive files):"
check_bin "/usr/bin/cat" ""
check_bin "/usr/bin/less" ""
check_bin "/usr/bin/vim" "WARNING: Can escape to shell"
check_bin "/usr/bin/vi" "WARNING: Can escape to shell"
check_bin "/usr/bin/nano" ""
check_bin "/usr/bin/head" ""
check_bin "/usr/bin/tail" ""
echo ""

echo "Shell Escapes:"
check_bin "/usr/bin/python3" "WARNING: Can spawn shells"
check_bin "/usr/bin/python" "WARNING: Can spawn shells"
check_bin "/usr/bin/perl" "WARNING: Can spawn shells"
check_bin "/usr/bin/ruby" "WARNING: Can spawn shells"
check_bin "/usr/bin/awk" ""
check_bin "/usr/bin/gawk" ""
check_bin "/usr/bin/find" "WARNING: Can execute commands via -exec"
echo ""

echo "Network Tools:"
check_bin "/usr/bin/wget" "WARNING: Can download payloads"
check_bin "/usr/bin/curl" "WARNING: Can download payloads"
check_bin "/usr/bin/nc" "WARNING: Can create reverse shells"
check_bin "/usr/bin/socat" "WARNING: Can create reverse shells"
echo ""

echo "File Writers (can overwrite system files if SUID):"
check_bin "/usr/bin/cp" ""
check_bin "/usr/bin/mv" ""
check_bin "/usr/bin/tee" ""
check_bin "/usr/bin/dd" ""
echo ""

echo "Note: These binaries are legitimate but should be monitored."
echo "See https://gtfobins.github.io/ for abuse techniques."
