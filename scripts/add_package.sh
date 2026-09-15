#!/usr/bin/env bash
# Добавить новый пакет в config/packages.yaml.
# Использование:
#   ./scripts/add_package.sh <name> <repo_url> [branch] [package_name] [ros_distro]
set -euo pipefail

NAME="${1:-}"
REPO="${2:-}"
BRANCH="${3:-main}"
PKG_NAME="${4:-$NAME}"
ROS_DISTRO="${5:-humble}"

if [ -z "$NAME" ] || [ -z "$REPO" ]; then
    echo "Usage: $0 <name> <repo_url> [branch] [package_name] [ros_distro]"
    exit 1
fi

if ! command -v yq &>/dev/null; then
    echo "ERROR: yq is required. Install: https://github.com/mikefarah/yq"
    exit 1
fi

if yq -e ".packages[] | select(.name == \"$NAME\")" config/packages.yaml &>/dev/null; then
    echo "ERROR: Package '$NAME' already exists in config/packages.yaml"
    exit 1
fi

yq -i ".packages += [{
  \"name\": \"$NAME\",
  \"repo\": \"$REPO\",
  \"branch\": \"$BRANCH\",
  \"package_name\": \"$PKG_NAME\",
  \"ros_distro\": \"$ROS_DISTRO\",
  \"cuda_arch\": {\"x86\": \"86\", \"agx\": \"87\", \"nano\": \"87\"},
  \"cmake_args\": \"-DCMAKE_BUILD_TYPE=Release\"
}]" config/packages.yaml

echo "Added package '$NAME' to config/packages.yaml"