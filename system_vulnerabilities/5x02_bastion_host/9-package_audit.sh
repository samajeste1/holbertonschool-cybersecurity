#!/bin/bash
# Identify unnecessary packages on a production web server

echo "=== Package Security Audit ==="
echo ""

DEV_COUNT=0
NET_COUNT=0
REMOTE_COUNT=0

echo "Checking for development tools..."
for pkg in gcc g++ make gdb cpp binutils linux-headers-generic build-essential; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        NAME=$(dpkg -l "$pkg" 2>/dev/null | grep '^ii' | awk '{print $2}')
        case "$pkg" in
            gcc) DESC="GNU C Compiler" ;;
            g++) DESC="GNU C++ Compiler" ;;
            make) DESC="Build automation" ;;
            gdb) DESC="Debugger" ;;
            cpp) DESC="C Preprocessor" ;;
            binutils) DESC="Binary utilities" ;;
            linux-headers*) DESC="Kernel headers" ;;
            build-essential) DESC="Build tools metapackage" ;;
            *) DESC="Development tool" ;;
        esac
        echo "  [FOUND] $NAME ($DESC)"
        DEV_COUNT=$((DEV_COUNT + 1))
    fi
done
echo ""

echo "Checking for network tools..."
for pkg in netcat-openbsd netcat-traditional ncat nmap tcpdump wireshark tshark socat; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        NAME=$(dpkg -l "$pkg" 2>/dev/null | grep '^ii' | awk '{print $2}')
        case "$pkg" in
            netcat*|ncat) DESC="Network Swiss Army Knife" ;;
            nmap) DESC="Network scanner" ;;
            tcpdump) DESC="Packet capture" ;;
            wireshark|tshark) DESC="Packet analyzer" ;;
            socat) DESC="Socket relay" ;;
            *) DESC="Network tool" ;;
        esac
        echo "  [FOUND] $NAME ($DESC)"
        NET_COUNT=$((NET_COUNT + 1))
    fi
done
echo ""

echo "Checking for remote access tools..."
for pkg in telnet rsh-client rlogin ftp xinetd; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        NAME=$(dpkg -l "$pkg" 2>/dev/null | grep '^ii' | awk '{print $2}')
        case "$pkg" in
            telnet) DESC="Insecure remote access" ;;
            rsh-client) DESC="Remote shell (insecure)" ;;
            rlogin) DESC="Remote login (insecure)" ;;
            ftp) DESC="FTP client (insecure)" ;;
            xinetd) DESC="Internet services daemon" ;;
            *) DESC="Remote access tool" ;;
        esac
        echo "  [FOUND] $NAME ($DESC)"
        REMOTE_COUNT=$((REMOTE_COUNT + 1))
    fi
done
echo ""

echo "Summary:"
echo "  Development tools: $DEV_COUNT found"
echo "  Network tools: $NET_COUNT found"
echo "  Remote access: $REMOTE_COUNT found"
echo ""
echo "Recommendation: Review and remove unnecessary packages."
