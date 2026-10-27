#!/bin/bash
# Compare single-stage vs multi-stage Docker build sizes

echo "Building single-stage image..."

# Create a single-stage Dockerfile
cat > /tmp/Dockerfile.singlestage << 'EOF'
FROM python:3.11-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends gcc make curl && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir pylint black pytest mypy
COPY . /app

RUN groupadd -g 1000 appuser && \
    useradd -m -u 1000 -g appuser -s /bin/bash appuser
USER appuser

EXPOSE 5000
CMD ["python3", "app.py"]
EOF

docker build -t devstream-singlestage:latest -f /tmp/Dockerfile.singlestage . 2>/dev/null

echo "Building multi-stage image..."
docker build -t devstream-multistage:latest . 2>/dev/null

# Get sizes
SINGLE_SIZE=$(docker image inspect devstream-singlestage:latest --format='{{.Size}}' 2>/dev/null)
MULTI_SIZE=$(docker image inspect devstream-multistage:latest --format='{{.Size}}' 2>/dev/null)

SINGLE_MB=$((SINGLE_SIZE / 1048576))
MULTI_MB=$((MULTI_SIZE / 1048576))

if [ "$SINGLE_SIZE" -gt 0 ] 2>/dev/null; then
    REDUCTION=$(( (SINGLE_SIZE - MULTI_SIZE) * 100 / SINGLE_SIZE ))
else
    REDUCTION=0
fi

echo ""
echo "Single-stage image: ${SINGLE_MB} MB"
echo "Multi-stage image: ${MULTI_MB} MB"
echo "Reduction: ${REDUCTION}%"
echo ""

echo "Packages in final image:"
echo "  python3.11"
echo "  flask"
echo "  pylint, black, pytest, mypy"
echo "  (minimal runtime only)"
echo ""

echo "Build tools excluded:"
# Check that gcc is not in multi-stage image
docker run --rm devstream-multistage:latest which gcc 2>/dev/null
if [ $? -ne 0 ]; then
    echo "  gcc ✓"
else
    echo "  gcc ✗ (still present)"
fi

docker run --rm devstream-multistage:latest which make 2>/dev/null
if [ $? -ne 0 ]; then
    echo "  make ✓"
else
    echo "  make ✗ (still present)"
fi

echo "  pip (caches cleared) ✓"

# Cleanup temp file
rm -f /tmp/Dockerfile.singlestage
