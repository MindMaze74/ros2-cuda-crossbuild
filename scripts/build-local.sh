#!/usr/bin/env bash
# Локальная сборка Docker-образа пакета.
# Использование: ./scripts/build-local.sh <package> <platform>
set -euo pipefail

PACKAGE="${1:-}"
PLATFORM="${2:-}"

if [ -z "$PACKAGE" ] || [ -z "$PLATFORM" ]; then
    echo "Usage: $0 <package> <platform>"
    echo "  platform: amd64 | arm64"
    exit 1
fi

REGISTRY="${REGISTRY:-ghcr.io}"
OWNER="${OWNER:-MindMaze74}"

case "$PLATFORM" in
    amd64) DOCKER_PLATFORM="linux/amd64" ;;
    arm64) DOCKER_PLATFORM="linux/arm64" ;;
    *) echo "Unknown platform: $PLATFORM"; exit 1 ;;
esac

if ! command -v yq &>/dev/null; then
    echo "ERROR: yq is required"
    exit 1
fi

REPO=$(yq -r ".packages[] | select(.name == \"$PACKAGE\") | .repo" config/packages.yaml)
BRANCH=$(yq -r ".packages[] | select(.name == \"$PACKAGE\") | .branch" config/packages.yaml)
PKG_NAME=$(yq -r ".packages[] | select(.name == \"$PACKAGE\") | .package_name" config/packages.yaml)
ROS_DISTRO=$(yq -r ".packages[] | select(.name == \"$PACKAGE\") | .ros_distro" config/packages.yaml)
CMAKE_ARGS=$(yq -r ".packages[] | select(.name == \"$PACKAGE\") | .cmake_args" config/packages.yaml)

docker buildx build \
    --platform "$DOCKER_PLATFORM" \
    --build-arg BASE_IMAGE="$REGISTRY/$OWNER/ros2-cuda-crossbuild/ros2-base-x86:latest" \
    --build-arg REPO_URL="$REPO" \
    --build-arg BRANCH="$BRANCH" \
    --build-arg PACKAGE_NAME="$PKG_NAME" \
    --build-arg ROS_DISTRO="$ROS_DISTRO" \
    --build-arg CMAKE_ARGS="$CMAKE_ARGS" \
    -t "ros2-package-$PACKAGE:$PLATFORM" \
    -f docker/Dockerfile.package \
    --load \
    .

echo "Built: ros2-package-$PACKAGE:$PLATFORM"