#!/bin/bash
# Inspect Docker image history to demonstrate secret exposure

IMAGE="${1:-devstream-vulnerable:latest}"

echo "Image: $IMAGE"
echo "Layer History:"

LAYER_NUM=0
docker history --no-trunc --format '{{.CreatedBy}}' "$IMAGE" 2>/dev/null | tac | while read -r line; do
    LAYER_NUM=$((LAYER_NUM + 1))
    SHORT=$(echo "$line" | cut -c1-60)

    if echo "$line" | grep -q 'chpasswd'; then
        echo "  Layer $LAYER_NUM: $SHORT  <- PASSWORD EXPOSED"
    elif echo "$line" | grep -qi 'DB_PASSWORD'; then
        echo "  Layer $LAYER_NUM: $SHORT  <- SECRET EXPOSED"
    elif echo "$line" | grep -qi 'DB_HOST\|DB_USER'; then
        echo "  Layer $LAYER_NUM: $SHORT"
    else
        echo "  Layer $LAYER_NUM: $SHORT"
    fi
done

echo ""
echo "Extracting secrets from history..."

# Extract root password from chpasswd layer
ROOT_PASS=$(docker history --no-trunc "$IMAGE" 2>/dev/null | grep 'chpasswd' | grep -oP "root:\K[^'|]+")
if [ -n "$ROOT_PASS" ]; then
    echo "  Root password: $ROOT_PASS"
fi

# Extract DB password from ENV layer
DB_PASS=$(docker inspect "$IMAGE" --format='{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep 'DB_PASSWORD' | cut -d= -f2)
if [ -n "$DB_PASS" ]; then
    echo "  DB Password: $DB_PASS"
fi

# Extract all ENV secrets
docker inspect "$IMAGE" --format='{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^DB_' | while read -r line; do
    echo "  ENV: $line"
done

echo ""
echo "CRITICAL: All ENV and RUN commands are permanently"
echo "visible in image layers. Never put secrets here!"
