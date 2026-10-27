#!/bin/bash
# Verify all kernel hardening parameters

echo "=== Kernel Hardening Verification ==="
echo ""

PASS=0
FAIL=0

check_param() {
    local param="$1"
    local expected="$2"
    local actual
    actual=$(sysctl -n "$param" 2>/dev/null)
    if [ "$actual" = "$expected" ]; then
        echo "  [PASS] $param = $actual"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $param = $actual (expected $expected)"
        FAIL=$((FAIL + 1))
    fi
}

echo "IP Forwarding:"
check_param "net.ipv4.ip_forward" "0"
check_param "net.ipv6.conf.all.forwarding" "0"
echo ""

echo "ICMP Redirects:"
check_param "net.ipv4.conf.all.accept_redirects" "0"
check_param "net.ipv4.conf.default.accept_redirects" "0"
check_param "net.ipv4.conf.all.send_redirects" "0"
check_param "net.ipv4.conf.default.send_redirects" "0"
echo ""

echo "Reverse Path Filtering:"
check_param "net.ipv4.conf.all.rp_filter" "1"
check_param "net.ipv4.conf.default.rp_filter" "1"
echo ""

echo "SYN Cookies:"
check_param "net.ipv4.tcp_syncookies" "1"
echo ""

echo "Source Routing:"
check_param "net.ipv4.conf.all.accept_source_route" "0"
check_param "net.ipv4.conf.default.accept_source_route" "0"
echo ""

echo "ICMP Configuration:"
check_param "net.ipv4.icmp_echo_ignore_broadcasts" "1"
check_param "net.ipv4.icmp_ignore_bogus_error_responses" "1"
echo ""

echo "Persistence Check:"
if [ -f /etc/sysctl.d/99-hardening.conf ]; then
    echo "  [PASS] /etc/sysctl.d/99-hardening.conf exists"
    PASS=$((PASS + 1))
else
    echo "  [FAIL] /etc/sysctl.d/99-hardening.conf missing"
    FAIL=$((FAIL + 1))
fi
echo ""

TOTAL=$((PASS + FAIL))
echo "Summary: ${PASS}/${TOTAL} checks passed"
if [ "$FAIL" -eq 0 ]; then
    echo "Kernel hardening: COMPLETE"
else
    echo "Kernel hardening: INCOMPLETE ($FAIL items need attention)"
fi
