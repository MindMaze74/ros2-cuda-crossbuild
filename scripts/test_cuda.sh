#!/usr/bin/env bash
set -euo pipefail

IMAGE="$1"
if [[ -z "$IMAGE" ]]; then
  echo "Usage: ./scripts/test_cuda.sh <image>"
  exit 1
fi

echo "Testing image: $IMAGE"
echo "1. CUDA version:"
docker run --rm "$IMAGE" nvcc --version

echo "2. ROS2 distro:"
docker run --rm "$IMAGE" rosversion -d

echo "3. Installed packages:"
docker run --rm "$IMAGE" ls -la /workspace/install

echo "4. Library check (CUDA runtime):"
docker run --rm "$IMAGE" ldd /workspace/install/lib/*/*.so 2>/dev/null | grep -i cuda || echo "No explicit CUDA libs found (may be statically linked)"
