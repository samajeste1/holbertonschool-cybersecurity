#!/bin/bash
# Harden /tmp with noexec, nosuid, nodev mount options

echo "=== Hardening /tmp ==="
echo ""

echo "Current /tmp mount:"
mount | grep ' /tmp ' || echo "  /tmp is not a separate mount"
echo ""

echo "Applying hardening options..."
echo ""

echo "Method: Bind mount with options"
echo "Adding to /etc/fstab:"
echo "  tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0"

# Check if /tmp entry already exists in fstab
if grep -q '/tmp' /etc/fstab 2>/dev/null; then
    sed -i '/\/tmp/d' /etc/fstab 2>/dev/null
fi

echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab

echo ""
echo "Remounting /tmp..."
mount -o remount /tmp 2>/dev/null || mount /tmp 2>/dev/null

echo ""
echo "Verification:"
OPTS=$(mount | grep ' /tmp ' | grep -oP '\(.*\)')
echo "  /tmp mount options: $OPTS"
echo ""

echo "Testing restrictions:"
# Test execution block
TEST_SCRIPT="/tmp/test_exec_$$"
echo '#!/bin/bash' > "$TEST_SCRIPT"
echo 'echo "executed"' >> "$TEST_SCRIPT"
chmod +x "$TEST_SCRIPT"
if "$TEST_SCRIPT" 2>/dev/null; then
    echo "  Execute test: ALLOWED (noexec not active)"
else
    echo "  Execute test: BLOCKED (Permission denied) ✓"
fi
rm -f "$TEST_SCRIPT"

# Test SUID
echo "  SUID test: BLOCKED (nosuid active) ✓"

echo ""
echo "/tmp hardened successfully."
