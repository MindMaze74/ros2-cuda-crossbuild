# ros2-cuda-crossbuild

Автоматическая кросс-платформенная сборка Docker-образов для ROS2-пакетов
с поддержкой CUDA. Три целевые платформы: x86_64, Jetson AGX Orin, Jetson Orin Nano.

## Быстрый старт

```bash
docker pull ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest
docker run --rm -it ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest nvcc --version
``` 

<!-- PACKAGES_TABLE:START -->
<!-- Секция сгенерирована автоматически из config/packages.yaml. -->
<!-- Не редактируйте вручную — правьте packages.yaml. -->

## Поддерживаемые пакеты

Всего пакетов: **1**. Матрица: пакет × 3 платформы (x86 / agx / nano).

| Пакет | Репозиторий | Ветка | ROS2 | x86 | agx | nano |
|---|---|---|---|---|---|---|
| `fastlio2` | [hku-mars/FAST_LIO](https://github.com/hku-mars/FAST_LIO.git) | `main` | `humble` | `86` | `87` | `87` |

Добавление нового пакета — одна запись в [`config/packages.yaml`](config/packages.yaml).
После пуша workflow `README Sync` автоматически обновит эту таблицу.

<!-- PACKAGES_TABLE:END -->
