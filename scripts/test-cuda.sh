#!/usr/bin/env bash
# Проверка CUDA в Docker-образе.
# Использование: ./scripts/test-cuda.sh <image>
set -euo pipefail

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
    echo "Usage: $0 <image>"
    exit 1
fi

docker run --rm "$IMAGE" bash -c '
    echo "=== 1. CUDA runtime ==="
    ldconfig -p | grep libcudart || exit 1

    echo "=== 2. CUDA compiler ==="
    nvcc --version

    echo "=== 3. CUDA libraries ==="
    ldconfig -p | grep -E "libcublas|libcufft" || true

    echo "All CUDA checks passed"
'