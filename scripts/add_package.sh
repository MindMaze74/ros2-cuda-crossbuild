#!/usr/bin/env bash
set -euo pipefail

# Генерация конфигурации для нового пакета
# Usage: ./scripts/add_package.sh <name> <repo_url> [branch]

NAME="${1:-}"
REPO="${2:-}"
BRANCH="${3:-main}"

if [ -z "$NAME" ] || [ -z "$REPO" ]; then
    echo "Usage: ./scripts/add_package.sh <name> <repo_url> [branch]"
    echo ""
    echo "Example:"
    echo "  ./scripts/add_package.sh my_slam https://github.com/user/my_slam.git humble"
    exit 1
fi

mkdir -p packages

cat > "packages/${NAME}.yaml" <<EOF
name: ${NAME}
repo: ${REPO}
branch: ${BRANCH}
ros_distro: humble
cuda_arch:
  x86: "86"
  agx: "87"
  nano: "87"
EOF

echo ""
echo "Created: packages/${NAME}.yaml"
echo ""
echo "To add to CI/CD, add '${NAME}' to the matrix.package list in .github/workflows/build.yml"
echo ""
echo "Then update the build-args in the build-packages job:"
echo "  REPO_URL=${REPO}"
echo "  BRANCH=${BRANCH}"
echo "  PACKAGE_NAME=${NAME}"
