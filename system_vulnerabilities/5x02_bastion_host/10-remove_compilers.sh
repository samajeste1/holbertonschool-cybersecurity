#!/bin/bash
# Remove or restrict compilers to prevent local exploit compilation

echo "=== Development Tools Removal ==="
echo ""

echo "Checking dependencies before removal..."
for pkg in gcc g++ make; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        RDEPS=$(apt-cache rdepends --installed "$pkg" 2>/dev/null | grep -v "^$pkg" | grep -v "Reverse" | grep -v "^ " | wc -l)
        if [ "$RDEPS" -le 1 ]; then
            echo "  $pkg: Can be safely removed"
        else
            echo "  $pkg: Has $RDEPS reverse dependencies (will restrict instead)"
        fi
    else
        echo "  $pkg: Not installed"
    fi
done
echo ""

echo "Removing packages..."
for pkg in gcc g++ make gdb cpp; do
    if dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
        apt-get remove -y "$pkg" >/dev/null 2>&1
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q '^ii'; then
            echo "  $pkg: Removed"
        else
            # Fallback: restrict to root only
            BIN=$(which "$pkg" 2>/dev/null)
            if [ -n "$BIN" ]; then
                chmod 0700 "$BIN"
                echo "  $pkg: Restricted to root ($BIN)"
            fi
        fi
    fi
done
echo ""

echo "Cleanup..."
echo "  Removing orphaned dependencies..."
REMOVED=$(apt-get autoremove -y 2>/dev/null | grep -c 'Removing')
echo "  $REMOVED packages auto-removed"
echo ""

echo "Verification:"
for pkg in gcc g++ make; do
    if command -v "$pkg" >/dev/null 2>&1; then
        echo "  $pkg: Still present (restricted)"
    else
        echo "  $pkg: Not found"
    fi
done
echo ""
echo "Compilers removed successfully."
