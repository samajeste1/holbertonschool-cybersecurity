#!/bin/bash
# Run the secure container with secrets provided at runtime
# Secrets are passed via environment variables — never hardcoded in Dockerfiles

# Build the secure image if not present
docker image inspect devstream-nosecrets:v1 >/dev/null 2>&1 || \
    docker build -t devstream-nosecrets:v1 . 2>/dev/null

echo "Running secure container with runtime secrets..."
echo ""
echo "Method: Environment variables via docker run -e"
echo "  Secrets are NOT stored in the image."
echo "  They exist only in the container's runtime environment."
echo ""

# Stop any previous instance
docker stop devstream-nosecrets 2>/dev/null
docker rm devstream-nosecrets 2>/dev/null

# Run with secrets passed at runtime
docker run -d \
    --name devstream-nosecrets \
    -e DB_HOST="${DB_HOST:-localhost}" \
    -e DB_USER="${DB_USER:-appuser}" \
    -e DB_PASSWORD="${DB_PASSWORD:-changeme}" \
    -p 5000:5000 \
    devstream-nosecrets:v1

echo "Container started: devstream-nosecrets"
echo ""

echo "Verification:"
echo "  Image ENV (no secrets):"
docker inspect devstream-nosecrets:v1 --format='{{range .Config.Env}}{{println .}}{{end}}' 2>/dev/null | grep -E '^DB_' || echo "    No DB secrets in image config"

echo ""
echo "  Container ENV (runtime only):"
docker exec devstream-nosecrets env 2>/dev/null | grep -E '^DB_' | while read -r line; do
    KEY=$(echo "$line" | cut -d= -f1)
    echo "    $KEY=<provided at runtime>"
done

echo ""
echo "Correct ways to provide secrets:"
echo "  1. docker run -e DB_PASSWORD=mypass  (CLI environment variable)"
echo "  2. docker run --env-file .env        (environment file, not in image)"
echo "  3. Docker secrets (Swarm mode)       (encrypted at rest)"
echo "  4. Vault/AWS Secrets Manager         (external secret management)"

# Cleanup
docker stop devstream-nosecrets 2>/dev/null
docker rm devstream-nosecrets 2>/dev/null
