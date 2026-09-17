# ros2-cuda-crossbuild

Автоматическая кросс-платформенная сборка Docker-образов для ROS2-пакетов
с поддержкой CUDA. Три целевые платформы: x86_64, Jetson AGX Orin,
Jetson Orin Nano.

## Быстрый старт

```bash
# 1. Скачиваем базовый образ для x86
docker pull ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest

# 2. Проверяем наличие CUDA (должно вывести версию nvcc)
docker run --rm -it ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest nvcc --version

# 3. Скачиваем готовый пакет FAST-LIO2 (кросс-сборка под AGX)
docker pull ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-package-fastlio2-agx-cross
```

<!-- PACKAGES_TABLE:START -->
<!-- Секция сгенерирована автоматически из config/packages.yaml. -->
<!-- Не редактируйте вручную — правьте packages.yaml. -->

## Поддерживаемые пакеты

Всего пакетов: **1**. Матрица: пакет × 3 платформы (x86 / agx / nano).

| Пакет | Репозиторий | Ветка | ROS2 | x86 | agx | nano |
|---|---|---|---|---|---|---|
| `fastlio2` | [ruiqichao/FAST_LIO2_GPU](https://github.com/ruiqichao/FAST_LIO2_GPU.git) | `main` | `humble/humble/jazzy` | `86` | `87` | `87` |

Добавление нового пакета — одна запись в [`config/packages.yaml`](config/packages.yaml).
После пуша workflow `README Sync` автоматически обновит эту таблицу.

<!-- PACKAGES_TABLE:END -->

## Способы сборки ARM64

1. **Кросс через QEMU** — на `ubuntu-latest` (по умолчанию).
2. **Нативно на Jetson** — при подключённом self-hosted runner'е,
   через флаг `build_native_arm`. Инструкция — [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md), раздел 3.
   
## Документация

- [docs/architecture.md](docs/architecture.md) — схема пайплайна (Mermaid)
- [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) — развёртывание, добавление пакета, self-hosted runner
- [docs/REPORT.md](docs/REPORT.md) — итоговый отчёт по практике
- [docs/adr/](docs/adr/) — принятые архитектурные решения

##  Платформенные детали

| Платформа | База | ROS2 | CUDA arch |
|---|---|---|---|
| x86_64 | `nvidia/cuda:12.9.0-devel-ubuntu22.04` | Humble | 86 |
| AGX Orin | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | Humble | 87 |
| Orin Nano | `nvidia/cuda:12.6.3-devel-ubuntu24.04` | Jazzy | 87 |


   

## Лицензия

Учебный проект. См. [docs/REPORT.md](docs/REPORT.md).
