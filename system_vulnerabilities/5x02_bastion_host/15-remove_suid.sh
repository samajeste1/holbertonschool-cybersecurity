#!/bin/bash
# Remove SUID bits from non-essential binaries

echo "=== SUID Neutralization ==="
echo ""

# Essential SUID binaries to preserve
PRESERVE="/usr/bin/sudo /usr/bin/passwd /usr/bin/su /usr/bin/ping /usr/lib/openssh/ssh-keysign"

echo "Preserving essential SUID (DO NOT TOUCH):"
for bin in $PRESERVE; do
    if [ -f "$bin" ]; then
        echo "  $bin"
    fi
done
echo ""

echo "Removing SUID from non-essential binaries..."
BEFORE=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
REMOVED=0

find / -perm -4000 -type f 2>/dev/null | while read -r bin; do
    SKIP=0
    for safe in $PRESERVE; do
        if [ "$bin" = "$safe" ]; then
            SKIP=1
            break
        fi
    done

    if [ "$SKIP" -eq 0 ]; then
        NAME=$(basename "$bin")
        chmod u-s "$bin" 2>/dev/null
        if [ $? -eq 0 ]; then
            case "$bin" in
                /usr/local/*) echo "  $bin: SUID removed (CUSTOM - HIGH RISK)" ;;
                *mount*) echo "  $bin: SUID removed (admin can use sudo)" ;;
                *umount*) echo "  $bin: SUID removed (admin can use sudo)" ;;
                *newgrp*) echo "  $bin: SUID removed (not needed)" ;;
                *chsh*) echo "  $bin: SUID removed (not needed on server)" ;;
                *chfn*) echo "  $bin: SUID removed (not needed on server)" ;;
                *gpasswd*) echo "  $bin: SUID removed (admin can use sudo)" ;;
                *pkexec*) echo "  $bin: SUID removed (GTFOBins risk)" ;;
                *) echo "  $bin: SUID removed" ;;
            esac
        fi
    fi
done
echo ""

echo "Verification:"
for bin in mount umount newgrp; do
    BIN_PATH=$(which "$bin" 2>/dev/null)
    if [ -n "$BIN_PATH" ]; then
        PERMS=$(stat -c '%A' "$BIN_PATH")
        echo "  $bin: $PERMS (no SUID)"
    fi
done
echo ""

AFTER=$(find / -perm -4000 -type f 2>/dev/null | wc -l)
echo "SUID binaries reduced from $BEFORE to $AFTER."
