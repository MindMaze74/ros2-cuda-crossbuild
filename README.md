# ros2-cuda-crossbuild

Автоматическая кросс-платформенная сборка Docker-образов для ROS2-пакетов
с поддержкой CUDA. Три целевые платформы: x86_64, Jetson AGX Orin, Jetson Orin Nano.

## Быстрый старт

```bash
docker pull ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest
docker run --rm -it ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest nvcc --version
``` 

<!-- PACKAGES_TABLE:START --><!-- PACKAGES_TABLE:END -->

# Документация

docs/architecture.md — схема пайплайна

docs/DEPLOYMENT.md — развёртывание

docs/adr/ — принятые архитектурные решения


# Architecture Decision Records

Короткие записи о принятых архитектурных решениях. Формат — [Michael Nygard ADR](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions).

| # | Решение | Статус |
|---|---|---|
| [0001](0001-why-qemu.md) | Кросс-сборка ARM64 через QEMU, а не нативно | Accepted |
| [0002](0002-why-jazzy-for-nano.md) | ROS2 Jazzy на Orin Nano вместо Humble | Accepted |
| [0003](0003-why-kitware-apt.md) | CMake из Kitware APT вместо apt/pip | Accepted |



## Порядок применения

```bash
cd ~/git/ros2-cuda-crossbuild

# 1. Workflow'ы
#    Заменить .github/workflows/build.yml
#    Создать .github/workflows/readme-sync.yml

# 2. Скрипты
chmod +x scripts/render-readme.sh

# 3. Документация
mkdir -p docs/adr
#    Создать docs/adr/README.md, 0001-why-qemu.md, 0002-why-jazzy-for-nano.md, 0003-why-kitware-apt.md
#    Заменить docs/architecture.md

# 4. README — добавить маркеры PACKAGES_TABLE

# 5. Локальная проверка рендера
./scripts/render-readme.sh
git diff README.md   # должна появиться таблица

# 6. Коммит
git add .github/ config/ docs/ scripts/ README.md
git commit -m "ci: digest pinning, per-job permissions, timeouts, cache, ADR, README sync"
git push origin feature/main-b