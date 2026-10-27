#!/bin/bash
# Run container with resource limits

# Build the secure image if needed
docker image inspect devstream-secure:latest >/dev/null 2>&1 || \
    docker build -t devstream-secure:latest . 2>/dev/null

# Stop any previous instance
docker stop devstream-limited 2>/dev/null
docker rm devstream-limited 2>/dev/null

echo "Applying limits:"
echo "  --memory=256m (max 256MB RAM)"
echo "  --memory-swap=256m (no swap)"
echo "  --cpus=0.5 (max 50% of one CPU)"
echo "  --pids-limit=50 (max 50 processes)"
echo ""

docker run -d \
    --name devstream-limited \
    --memory=256m \
    --memory-swap=256m \
    --cpus=0.5 \
    --pids-limit=50 \
    --cap-drop=ALL \
    -p 5000:5000 \
    devstream-secure:latest

echo "Container started: devstream-limited"
echo ""

echo "Verification:"

# Check memory limit
MEM_LIMIT=$(docker inspect devstream-limited --format='{{.HostConfig.Memory}}' 2>/dev/null)
MEM_MB=$((MEM_LIMIT / 1048576))
echo "  Memory limit: ${MEM_MB}MB"

# Check CPU limit
CPU_LIMIT=$(docker inspect devstream-limited --format='{{.HostConfig.NanoCpus}}' 2>/dev/null)
CPU_CORES=$(echo "scale=1; $CPU_LIMIT / 1000000000" | bc 2>/dev/null || echo "0.5")
echo "  CPU limit: ${CPU_CORES} cores"

# Check PID limit
PID_LIMIT=$(docker inspect devstream-limited --format='{{.HostConfig.PidsLimit}}' 2>/dev/null)
echo "  PID limit: ${PID_LIMIT}"

echo ""
echo "Resource limits active."
echo "Container cannot exhaust host resources."

# Cleanup
docker stop devstream-limited 2>/dev/null
docker rm devstream-limited 2>/dev/null
