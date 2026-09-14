#!/usr/bin/env bash
set -euo pipefail

# Локальная сборка образов
# Usage:
#   ./scripts/build.sh base x86      — собрать базовый образ x86
#   ./scripts/build.sh base agx      — собрать базовый образ AGX Orin
#   ./scripts/build.sh base nano     — собрать базовый образ Orin Nano
#   ./scripts/build.sh pkg fastlio2 x86   — собрать пакет fastlio2 для x86

MODE="${1:-}"
PLATFORM="${2:-}"
PKG="${3:-}"

if [ -z "$MODE" ] || [ -z "$PLATFORM" ]; then
    echo "Usage:"
    echo "  ./scripts/build.sh base <x86|agx|nano>"
    echo "  ./scripts/build.sh pkg <package_name> <x86|agx|nano>"
    exit 1
fi

# Определение CUDA arch
case "$PLATFORM" in
    x86)  CUDA_ARCH="86" ;;
    agx|nano) CUDA_ARCH="87" ;;
    *) echo "Unknown platform: $PLATFORM"; exit 1 ;;
esac

case "$MODE" in
    base)
        echo "Building base image for: $PLATFORM"
        docker build \
            --platform $([ "$PLATFORM" = "x86" ] && echo "linux/amd64" || echo "linux/arm64") \
            -t ros2-base-${PLATFORM}:latest \
            -f docker/Dockerfile.base.${PLATFORM} .
        echo "Done: ros2-base-${PLATFORM}:latest"
        ;;

    pkg)
        if [ -z "$PKG" ]; then
            echo "Usage: ./scripts/build.sh pkg <package_name> <x86|agx|nano>"
            exit 1
        fi
        echo "Building package: $PKG for: $PLATFORM"
        docker build \
            --platform $([ "$PLATFORM" = "x86" ] && echo "linux/amd64" || echo "linux/arm64") \
            --build-arg BASE_IMAGE=ros2-base-${PLATFORM}:latest \
            --build-arg CUDA_ARCHITECTURES=${CUDA_ARCH} \
            --build-arg REPO_URL=https://github.com/Ericsii/FAST_LIO_ROS2.git \
            --build-arg BRANCH=main \
            --build-arg PACKAGE_NAME=fast_lio \
            -t ros2-package-${PKG}:${PLATFORM} \
            -f docker/Dockerfile.package .
        echo "Done: ros2-package-${PKG}:${PLATFORM}"
        ;;

    *)
        echo "Unknown mode: $MODE"
        echo "Use 'base' or 'pkg'"
        exit 1
        ;;
esac
