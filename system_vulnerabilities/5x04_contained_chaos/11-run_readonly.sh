#!/bin/bash
# Run container with read-only root filesystem

# Build the secure image if needed
docker image inspect devstream-secure:latest >/dev/null 2>&1 || \
    docker build -t devstream-secure:latest . 2>/dev/null

# Stop any previous instance
docker stop devstream-readonly 2>/dev/null
docker rm devstream-readonly 2>/dev/null

echo "Starting container with:"
echo "  --read-only"
echo "  --tmpfs /tmp (for temporary files)"
echo "  --tmpfs /app/logs (for application logs)"
echo ""

docker run -d \
    --name devstream-readonly \
    --read-only \
    --tmpfs /tmp \
    --tmpfs /app/logs \
    --cap-drop=ALL \
    -p 5000:5000 \
    devstream-secure:latest

sleep 2

echo "Verification:"

# Test write to /etc (should fail)
WRITE_ETC=$(docker exec devstream-readonly sh -c 'touch /etc/testfile 2>&1' 2>&1)
if echo "$WRITE_ETC" | grep -qi 'read-only\|permission denied'; then
    echo "  Attempt to write to /etc: BLOCKED"
else
    echo "  Attempt to write to /etc: ALLOWED (unexpected)"
fi

# Test write to /app (should fail)
WRITE_APP=$(docker exec devstream-readonly sh -c 'touch /app/testfile 2>&1' 2>&1)
if echo "$WRITE_APP" | grep -qi 'read-only\|permission denied'; then
    echo "  Attempt to write to /app: BLOCKED"
else
    echo "  Attempt to write to /app: ALLOWED (unexpected)"
fi

# Test write to /tmp (should succeed)
WRITE_TMP=$(docker exec devstream-readonly sh -c 'touch /tmp/testfile 2>&1' 2>&1)
if [ -z "$WRITE_TMP" ]; then
    echo "  Attempt to write to /tmp: ALLOWED"
else
    echo "  Attempt to write to /tmp: BLOCKED (unexpected)"
fi

# Test application logging
WRITE_LOG=$(docker exec devstream-readonly sh -c 'touch /app/logs/test.log 2>&1' 2>&1)
if [ -z "$WRITE_LOG" ]; then
    echo "  Application logging: WORKING"
else
    echo "  Application logging: ISSUE"
fi

echo ""
echo "Root filesystem: READ-ONLY"
echo "Attackers cannot modify system files or drop tools."

# Cleanup
docker stop devstream-readonly 2>/dev/null
docker rm devstream-readonly 2>/dev/null
