#!/usr/bin/env bash
# Комплексная проверка образа: CUDA + ROS2 + артефакты.
# Использование: ./scripts/verify-image.sh <image> [ros_distro]
set -euo pipefail

IMAGE="${1:-}"
ROS_DISTRO="${2:-humble}"

if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image> [ros_distro]"
    exit 1
fi

docker run --rm "$IMAGE" bash -c "
    set -e
    echo '=== 1. CUDA ==='
    nvcc --version

    echo '=== 2. ROS2 ==='
    source /opt/ros/${ROS_DISTRO}/setup.bash
    echo ROS_DISTRO=\$ROS_DISTRO

    echo '=== 3. Install artifacts ==='
    ls -la /opt/ros_ws/install/

    echo '=== 4. CUDA libraries ==='
    ldconfig -p | grep libcudart || true

    echo 'All checks passed'
"