#!/bin/bash
# Analyze the policy of any package given as argument

if [ -z "$1" ]; then
    echo "Usage: $0 <package_name>"
    exit 1
fi

PACKAGE="$1"

echo "=== Package Policy Analysis ==="
echo ""

# Get policy information
POLICY=$(apt-cache policy "$PACKAGE" 2>/dev/null)

if [ -z "$POLICY" ]; then
    echo "Package '$PACKAGE' not found."
    exit 1
fi

INSTALLED=$(echo "$POLICY" | grep 'Installed:' | awk '{print $2}')
CANDIDATE=$(echo "$POLICY" | grep 'Candidate:' | awk '{print $2}')

echo "Package: $PACKAGE"
echo "Installed: $INSTALLED"
echo "Candidate: $CANDIDATE"
echo ""

echo "Available versions:"
printf "  %-25s %-9s %s\n" "Version" "Priority" "Repository"

# Parse version table
echo "$POLICY" | awk '/Version table/,0' | grep -E '^\s+\*?\s+[0-9]|^\s+[0-9]+\s' | while read -r line; do
    if echo "$line" | grep -qE '^\s+\*?\s+[0-9]'; then
        VERSION=$(echo "$line" | awk '{print $NF}')
    else
        PRIORITY=$(echo "$line" | awk '{print $1}')
        REPO=$(echo "$line" | awk '{print $2, $3}' | sed 's|http[s]*://[^ ]* ||')
        printf "  %-25s %-9s %s\n" "$VERSION" "$PRIORITY" "$REPO"
    fi
done
echo ""

echo "Analysis:"
# Check for security update
if echo "$POLICY" | grep -q "security"; then
    SEC_VER=$(echo "$POLICY" | awk '/Version table/,0' | grep -B1 'security' | head -1 | awk '{print $NF}')
    if [ "$INSTALLED" != "$CANDIDATE" ]; then
        echo "  Security update available: YES"
        # Count versions between installed and candidate
        DELTA=$(echo "$POLICY" | awk '/Version table/,0' | grep -cE '^\s+\*?\s+[0-9]')
        echo "  Version delta: $DELTA releases behind security"
        echo "  Recommendation: Update to $CANDIDATE"
    else
        echo "  Security update available: NO"
        echo "  Package is up to date."
    fi
else
    if [ "$INSTALLED" != "$CANDIDATE" ]; then
        echo "  Security update available: NO (update is non-security)"
        echo "  Recommendation: Review before updating"
    else
        echo "  Security update available: NO"
        echo "  Package is up to date."
    fi
fi
