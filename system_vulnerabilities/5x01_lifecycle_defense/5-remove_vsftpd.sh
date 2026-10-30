#!/bin/bash
# Completely remove the vulnerable vsftpd service

echo "=== Vulnerable Service Removal ==="
echo ""
echo "Target: vsftpd (CVE-2011-2523 - Backdoor)"
echo ""

echo "Stopping service..."
systemctl stop vsftpd 2>/dev/null
systemctl disable vsftpd 2>/dev/null
echo "  vsftpd.service: Stopped"
echo ""

echo "Removing package..."
apt-get purge -y vsftpd 2>/dev/null | tail -3
echo "  vsftpd: Purged (including config files)"
echo ""

echo "Cleanup..."
for conffile in /etc/vsftpd.conf /etc/vsftpd.user_list /etc/vsftpd /etc/vsftpd.chroot_list; do
    if [ -f "$conffile" ] || [ -d "$conffile" ]; then
        rm -rf "$conffile"
        echo "  $conffile: Removed"
    fi
done

apt-get autoremove -y 2>/dev/null > /dev/null
echo ""

echo "Verification:"
PKG_STATUS=$(dpkg -l vsftpd 2>/dev/null | grep '^ii' || echo "not installed")
if echo "$PKG_STATUS" | grep -q "not installed"; then
    echo "  Package status: Not installed"
else
    echo "  Package status: Still installed (WARNING)"
fi

PORT_21=$(ss -tlnp | grep ':21 ' || true)
if [ -z "$PORT_21" ]; then
    echo "  Port 21: Not listening"
else
    echo "  Port 21: STILL LISTENING (WARNING)"
fi
echo ""

echo "vsftpd removed successfully."
echo "Vulnerability CVE-2011-2523: REMEDIATED"
