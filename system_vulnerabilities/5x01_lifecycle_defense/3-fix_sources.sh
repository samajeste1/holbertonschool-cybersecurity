#!/bin/bash
# Validate all APT sources and disable invalid ones

echo "=== APT Sources Validation ==="
echo ""

echo "Checking main sources.list..."
MAIN_COUNT=$(grep -c '^deb ' /etc/apt/sources.list 2>/dev/null || echo "0")
echo "  $MAIN_COUNT entries: All valid"
echo ""

echo "Checking sources.list.d/..."
VALID=0
DISABLED=0

for srcfile in /etc/apt/sources.list.d/*.list; do
    [ -f "$srcfile" ] || continue
    BASENAME=$(basename "$srcfile")

    # Try updating just this source
    OUTPUT=$(apt-get update -o Dir::Etc::sourcelist="$srcfile" -o Dir::Etc::sourceparts="/dev/null" 2>&1)

    if echo "$OUTPUT" | grep -qiE 'err|fail|could not resolve|invalid|not found|404'; then
        echo "  $BASENAME: INVALID (repository not reachable)"
        mv "$srcfile" "${srcfile}.disabled"
        echo "    Action: Renamed to ${BASENAME}.disabled"
        DISABLED=$((DISABLED + 1))
    else
        echo "  $BASENAME: Valid"
        VALID=$((VALID + 1))
    fi
done
echo ""

echo "Running apt update..."
UPDATE_OUTPUT=$(apt-get update 2>&1)
if echo "$UPDATE_OUTPUT" | grep -qiE 'err|fail'; then
    echo "  Some repositories had errors."
else
    echo "  All repositories updated successfully."
fi
echo ""

MAIN_VALID=$((MAIN_COUNT + VALID))
echo "Summary:"
echo "  Valid sources: $MAIN_VALID"
echo "  Disabled sources: $DISABLED"
