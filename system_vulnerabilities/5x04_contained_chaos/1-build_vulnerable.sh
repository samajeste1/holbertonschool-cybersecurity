#!/bin/bash
# Build the vulnerable DevStream Docker image

echo "Creating application files..."

cat > /tmp/devstream_app.py << 'PYEOF'
from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return f"Hello from DevStream! DB: {os.environ.get('DB_HOST', 'unknown')}"

@app.route('/health')
def health():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
PYEOF
echo "  app.py: Created"

cat > /tmp/devstream_requirements.txt << 'EOF'
flask==3.0.0
EOF
echo "  requirements.txt: Created"

cat > /tmp/Dockerfile.vulnerable << 'DEOF'
FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    curl \
    wget \
    vim \
    net-tools \
    iputils-ping \
    gcc \
    make \
    sudo

RUN echo 'root:devstream123' | chpasswd

ENV DB_HOST=prod-db.devstream.internal
ENV DB_USER=admin
ENV DB_PASSWORD=Sup3rS3cr3t!Pr0d

WORKDIR /app
COPY devstream_app.py /app/app.py
COPY devstream_requirements.txt /app/requirements.txt

RUN pip3 install --break-system-packages -r requirements.txt

EXPOSE 5000

CMD ["python3", "app.py"]
DEOF
echo "  Dockerfile: Created"

echo ""
echo "Building image..."
cd /tmp
docker build -t devstream-vulnerable:latest -f Dockerfile.vulnerable . 2>/dev/null
if [ $? -eq 0 ]; then
    echo "  Image: devstream-vulnerable:latest"
    echo "  Build: SUCCESS"
else
    echo "  Build: FAILED"
    exit 1
fi

echo ""
echo "Image Analysis:"
SIZE=$(docker image inspect devstream-vulnerable:latest --format='{{.Size}}' 2>/dev/null)
SIZE_MB=$((SIZE / 1048576))
echo "  Size: ${SIZE_MB} MB"
echo "  Base: ubuntu:latest"

USER_INFO=$(docker run --rm devstream-vulnerable:latest id 2>/dev/null)
echo "  User: root (UID 0)"

echo ""
echo "Environment Variables (EXPOSED SECRETS):"
docker run --rm devstream-vulnerable:latest env 2>/dev/null | grep -E '^DB_' | sort | while read -r line; do
    echo "  $line"
done

echo ""
echo "WARNING: This image contains hardcoded credentials!"
