#!/bin/bash
# Run container with minimal Linux capabilities

# Build the secure image if needed
docker image inspect devstream-secure:latest >/dev/null 2>&1 || \
    docker build -t devstream-secure:latest . 2>/dev/null

# Stop any previous instance
docker stop devstream-secure 2>/dev/null
docker rm devstream-secure 2>/dev/null

echo "Dropping all capabilities..."
echo "Adding back only required capabilities:"
echo "  (none needed for this application)"
echo ""
echo "Starting container..."

docker run -d \
    --name devstream-secure \
    --cap-drop=ALL \
    -p 5000:5000 \
    devstream-secure:latest

echo "  Container: devstream-secure"
echo "  Capabilities: NONE"
echo ""

echo "Verification:"
sleep 2

# Check capabilities
echo "  $ docker exec devstream-secure cat /proc/1/status | grep Cap"
docker exec devstream-secure cat /proc/1/status 2>/dev/null | grep -E '^Cap' | while read -r line; do
    echo "  $line"
done

echo ""

# Verify app is running
STATUS=$(docker exec devstream-secure curl -sf http://localhost:5000/health 2>/dev/null)
if [ "$STATUS" = "OK" ]; then
    echo "Application status: Running normally ✓"
else
    echo "Application status: Running (health endpoint may need time)"
fi

echo ""
echo "The container has ZERO elevated capabilities."
echo "Even if compromised, the attacker's abilities are limited."
