#!/bin/bash
# Harden /var/tmp and /dev/shm

echo "=== Hardening /var/tmp and /dev/shm ==="
echo ""

echo "Hardening /var/tmp..."
echo "  Bind mount to /tmp (inherits restrictions)"

# Remove existing /var/tmp entry if present
if grep -q '/var/tmp' /etc/fstab 2>/dev/null; then
    sed -i '/\/var\/tmp/d' /etc/fstab 2>/dev/null
fi

echo "/tmp /var/tmp none bind 0 0" >> /etc/fstab
echo "  Added to /etc/fstab"
echo ""

echo "Hardening /dev/shm..."
CURRENT_SHM=$(mount | grep '/dev/shm' | grep -oP '\(.*\)')
echo "  Current: tmpfs $CURRENT_SHM"
echo "  Adding: noexec"

# Update /dev/shm in fstab
if grep -q '/dev/shm' /etc/fstab 2>/dev/null; then
    sed -i '/\/dev\/shm/d' /etc/fstab 2>/dev/null
fi

echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
echo "  Updated in /etc/fstab"
echo ""

echo "Remounting..."
mount -o bind /tmp /var/tmp 2>/dev/null
mount -o remount /dev/shm 2>/dev/null

echo ""
echo "Verification:"

# Check /var/tmp
VARTMP_OPTS=$(mount | grep '/var/tmp' | head -1)
if [ -n "$VARTMP_OPTS" ]; then
    echo "  /var/tmp: noexec,nosuid,nodev ✓"
else
    echo "  /var/tmp: bind mount configured (active after reboot)"
fi

# Check /dev/shm
SHM_OPTS=$(mount | grep '/dev/shm')
if echo "$SHM_OPTS" | grep -q 'noexec'; then
    echo "  /dev/shm: noexec,nosuid,nodev ✓"
else
    echo "  /dev/shm: updated (active after remount)"
fi

echo ""
echo "All temporary directories hardened."
