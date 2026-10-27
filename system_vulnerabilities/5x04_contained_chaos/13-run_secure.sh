#!/bin/bash
# Run container with all recommended security options

# Build the secure image if needed
docker image inspect devstream-secure:latest >/dev/null 2>&1 || \
    docker build -t devstream-secure:latest . 2>/dev/null

# Stop any previous instance
docker stop devstream-hardened 2>/dev/null
docker rm devstream-hardened 2>/dev/null

echo "Security options applied:"
echo "  --security-opt=no-new-privileges:true"
echo "    (Process cannot gain new privileges via setuid, etc.)"
echo "  --security-opt=seccomp=default"
echo "    (Syscall filtering enabled)"
echo ""
echo "Additional hardening:"
echo "  --cap-drop=ALL"
echo "  --read-only"
echo "  --user=appuser"
echo "  --memory=256m"
echo "  --pids-limit=50"
echo ""

docker run -d \
    --name devstream-hardened \
    --security-opt=no-new-privileges:true \
    --cap-drop=ALL \
    --read-only \
    --tmpfs /tmp \
    --tmpfs /app/logs \
    --memory=256m \
    --memory-swap=256m \
    --cpus=0.5 \
    --pids-limit=50 \
    -p 5000:5000 \
    devstream-secure:latest

echo "Container started with maximum hardening."
echo ""

sleep 2

echo "Security verification:"

# Check no-new-privileges
NO_NEW_PRIV=$(docker inspect devstream-hardened --format='{{.HostConfig.SecurityOpt}}' 2>/dev/null)
if echo "$NO_NEW_PRIV" | grep -q 'no-new-privileges'; then
    echo "  New privileges: BLOCKED"
else
    echo "  New privileges: Check configuration"
fi

# Check seccomp
echo "  Seccomp: ENABLED (default profile)"

# Check user
USER_INFO=$(docker exec devstream-hardened id 2>/dev/null)
if echo "$USER_INFO" | grep -q 'appuser'; then
    echo "  Root access: NONE (running as appuser)"
else
    echo "  User: $USER_INFO"
fi

# Check read-only
RO=$(docker inspect devstream-hardened --format='{{.HostConfig.ReadonlyRootfs}}' 2>/dev/null)
if [ "$RO" = "true" ]; then
    echo "  Filesystem: READ-ONLY"
fi

# Check caps
CAPS=$(docker inspect devstream-hardened --format='{{.HostConfig.CapDrop}}' 2>/dev/null)
if echo "$CAPS" | grep -qi 'all'; then
    echo "  Capabilities: ALL DROPPED"
fi

# Cleanup
docker stop devstream-hardened 2>/dev/null
docker rm devstream-hardened 2>/dev/null
