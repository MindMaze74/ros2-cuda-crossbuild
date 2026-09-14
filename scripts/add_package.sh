#!/usr/bin/env bash
set -euo pipefail

NAME="$1"
REPO="$2"
BRANCH="${3:-main}"

if [[ -z "$NAME" || -z "$REPO" ]]; then
  echo "Usage: ./scripts/add_package.sh <name> <repo> [branch]"
  exit 1
fi

cat > "packages/${NAME}.yaml" <<EOF
name: ${NAME}
repo: ${REPO}
branch: ${BRANCH}
ros_distro: humble
cuda_arch: "87"
EOF

echo ""
echo "Готово: создан packages/${NAME}.yaml"
echo ""
echo "Добавьте в .github/workflows/build-packages.yml в matrix.package:"
echo "  - ${NAME}"
echo ""
echo "В шаге build-args укажите:"
echo "  REPO_URL=${REPO}"
echo "  BRANCH=${BRANCH}"
echo "  PACKAGE_NAME=${NAME}"
