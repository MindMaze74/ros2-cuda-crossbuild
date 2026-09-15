#!/usr/bin/env bash
# ============================================================================
# Проверка ROS2 в Docker-образе
# ============================================================================
# Использование: ./scripts/test-ros2.sh <image> <package_name> <ros_distro>
# ============================================================================
set -euo pipefail

IMAGE="${1:-}"
PACKAGE="${2:-}"
ROS_DISTRO="${3:-humble}"

if [ -z "$IMAGE" ] || [ -z "$PACKAGE" ]; then
    echo "Usage: $0 <image> <package_name> [ros_distro]"
    exit 1
fi

docker run --rm "$IMAGE" bash -c "
    source /opt/ros/${ROS_DISTRO}/setup.bash
    echo 'ROS_DISTRO=' \$ROS_DISTRO
    ros2 --version

    source /opt/ros_ws/install/setup.bash
    ros2 pkg list | grep -i '${PACKAGE}' || exit 1
    echo 'Package ${PACKAGE} registered'
"
