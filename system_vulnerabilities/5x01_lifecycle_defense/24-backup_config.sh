#!/bin/bash
# Export all patch management configuration to a timestamped archive

echo "=== Configuration Backup ==="
echo ""

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/backups"
ARCHIVE="$BACKUP_DIR/patch-config-${TIMESTAMP}.tar.gz"
TMPDIR=$(mktemp -d)

echo "Collecting configuration files..."

# Collect all configuration files
FILES=""
for f in \
    /etc/apt/apt.conf.d/20auto-upgrades \
    /etc/apt/apt.conf.d/50unattended-upgrades \
    /etc/apt/sources.list \
    /var/log/package_holds.log; do
    if [ -f "$f" ]; then
        cp --parents "$f" "$TMPDIR/" 2>/dev/null
        echo "  $f"
        FILES="$FILES $f"
    fi
done

# Collect sources.list.d
for f in /etc/apt/sources.list.d/*; do
    if [ -f "$f" ]; then
        cp --parents "$f" "$TMPDIR/" 2>/dev/null
        echo "  $f"
    fi
done

# Collect systemd timer overrides
for d in /etc/systemd/system/apt-daily.timer.d /etc/systemd/system/apt-daily-upgrade.timer.d; do
    if [ -d "$d" ]; then
        for f in "$d"/*; do
            if [ -f "$f" ]; then
                cp --parents "$f" "$TMPDIR/" 2>/dev/null
                echo "  $f"
            fi
        done
    fi
done
echo ""

echo "Creating archive..."
mkdir -p "$BACKUP_DIR"
tar -czf "$ARCHIVE" -C "$TMPDIR" . 2>/dev/null
echo "  $ARCHIVE"
echo ""

# Count files and size
FILE_COUNT=$(tar -tzf "$ARCHIVE" 2>/dev/null | grep -cv '/$')
SIZE=$(du -h "$ARCHIVE" 2>/dev/null | awk '{print $1}')
echo "Archive contents:"
echo "  $FILE_COUNT files, ${SIZE} total"
echo ""

# Generate checksum
SHA=$(sha256sum "$ARCHIVE" 2>/dev/null | awk '{print $1}')
echo "SHA256: $SHA"
echo ""

# Cleanup
rm -rf "$TMPDIR"

echo "Backup complete."
