#!/usr/bin/env bash
set -euo pipefail

# Тестирование собранного Docker-образа
# Usage: ./scripts/test_cuda.sh <image>

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "Usage: ./scripts/test_cuda.sh <image>"
    echo "Example: ./scripts/test_cuda.sh ros2-package-fastlio2:x86"
    exit 1
fi

echo "============================================"
echo "Testing image: $IMAGE"
echo "============================================"
echo ""

echo "=== 1. CUDA Compiler ==="
docker run --rm "$IMAGE" nvcc --version
echo ""

echo "=== 2. ROS2 Version ==="
docker run --rm "$IMAGE" bash -c "source /opt/ros/humble/setup.bash && echo \$ROS_DISTRO"
echo ""

echo "=== 3. Build Artifacts ==="
docker run --rm "$IMAGE" ls -la /workspace/install/
echo ""

echo "=== 4. ROS2 Package List ==="
docker run --rm "$IMAGE" bash -c "source /opt/ros/humble/setup.bash && source /workspace/install/setup.bash && ros2 pkg list" 2>/dev/null || echo "(ros2 pkg list requires a running ROS2 daemon)"
echo ""

echo "=== 5. CUDA Libraries ==="
docker run --rm "$IMAGE" bash -c "ldconfig -p | grep -i cuda | head -10" 2>/dev/null || echo "ldconfig not available"
echo ""

echo "============================================"
echo "All checks completed for: $IMAGE"
echo "============================================"
