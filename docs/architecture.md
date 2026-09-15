# Архитектура системы

## Компоненты

1. **Базовые образы** (`docker/Dockerfile.base.*`)
   - ROS2 Humble/Jazzy + CUDA Toolkit + зависимости
   - Публикуются в GHCR как `ros2-base-<platform>:latest`

2. **Шаблон пакета** (`docker/Dockerfile.package`)
   - Принимает `REPO_URL`, `BRANCH`, `PACKAGE_NAME`, `ROS_DISTRO`, `CUDA_ARCHITECTURES`
   - Multi-stage build: builder + runtime

3. **Конфигурация** (`config/packages.yaml`)
   - Единая точка управления списком пакетов
   - Добавление пакета = 1 запись

4. **CI/CD** (`.github/workflows/build.yml`)
   - Динамическая матрица из `config/packages.yaml`
   - Триггеры: push, tags, workflow_dispatch
   - Кеширование через `type=registry`

## Поток сборки

1. Push в main/feature → триггер workflow
2. Job `setup` читает `packages.yaml` → генерирует матрицу
3. Job `build-packages` параллельно собирает комбинации (пакет × платформа)
4. Каждый образ тестируется (CUDA, ROS2, артефакты)
5. Публикация в ghcr.io