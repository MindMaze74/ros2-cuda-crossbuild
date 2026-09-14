#!/usr/bin/env bash
set -euo pipefail

case "$1" in
  base)
    if [[ "$2" == "x86" ]]; then
      docker build -t ros2-base-x86 -f docker/Dockerfile.base.x86 .
    elif [[ "$2" == "jetson" ]]; then
      docker build -t ros2-base-jetson -f docker/Dockerfile.base.jetson .
    else
      echo "Usage: ./scripts/build.sh base [x86|jetson]"
      exit 1
    fi
    ;;
  pkg)
    PKG="$2"
    PLATFORM="$3"
    if [[ -z "$PKG" || -z "$PLATFORM" ]]; then
      echo "Usage: ./scripts/build.sh pkg <package> <x86|agx|nano>"
      exit 1
    fi

    BASE_TAG="ros2-base-${PLATFORM}"
    CUDA_ARCH=$([[ "$PLATFORM" == "x86" ]] && echo "86" || echo "87")

    docker build \
      --build-arg BASE_IMAGE="$BASE_TAG" \
      --build-arg CUDA_ARCHITECTURES="$CUDA_ARCH" \
      --build-arg REPO_URL="https://github.com/Ericsii/FAST_LIO_ROS2.git" \
      --build-arg BRANCH="main" \
      --build-arg PACKAGE_NAME="$PKG" \
      -t ros2-package-${PKG}:${PLATFORM} \
      -f docker/Dockerfile.package .
    ;;
  *)
    echo "Usage: ./scripts/build.sh {base|pkg} ..."
    exit 1
    ;;
esac
