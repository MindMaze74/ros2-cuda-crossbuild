# ROS2 CUDA Cross-Build System — Вариант A (Humble All)

Система автоматической кросс-платформенной сборки Docker-образов для ROS2-пакетов с поддержкой CUDA. Обеспечивает сборку под три целевые платформы: x86_64, Jetson AGX Orin и Jetson Orin Nano.

Все платформы используют единый стек — **ROS2 Humble** на **Ubuntu 22.04**.

---

## Оглавление

1. [Архитектура системы](#архитектура-системы)
2. [Платформы и образы](#платформы-и-образы)
3. [Ограничения и обоснование решений](#ограничения-и-обоснование-решений)
4. [Структура репозитория](#структура-репозитория)
5. [Развёртывание CI/CD](#развёртывание-cicd)
6. [Добавление нового пакета](#добавление-нового-пакета)
7. [Локальная сборка без CI](#локальная-сборка-без-ci)
8. [Подтверждение наличия CUDA](#подтверждение-наличия-cuda)
9. [Настройка self-hosted ARM-раннеров](#настройка-self-hosted-arm-раннеров)
10. [Ссылки и источники](#ссылки-и-источники)

---

## Архитектура системы

Система состоит из двух уровней Docker-образов:

```
┌─────────────────────────────────────────────────────────────┐
│                     CI/CD Pipeline                          │
│                   GitHub Actions + Buildx                   │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │   Base x86  │  │  Base AGX   │  │  Base Nano  │          │
│  │  (Humble +  │  │  (Humble +  │  │  (Humble +  │          │
│  │   CUDA)     │  │   CUDA)     │  │   CUDA)     │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                 │
│         └────────────────┴────────────────┘                 │
│                          │                                  │
│                    ┌─────▼─────┐                            │
│                    │ Dockerfile │                           │
│                    │ .package   │                           │
│                    │ (универсал.)│                          │
│                    └─────┬─────┘                            │
│                          │                                  │
│         ┌────────────────┼────────────────┐                 │
│         │                │                │                 │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐          │
│  │  Package x86 │  │ Package AGX │  │ Package Nano│         │
│  │ (fast_lio)   │  │ (fast_lio)  │  │ (fast_lio)  │         │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                 │
│         └────────────────┴────────────────┘                 │
│                          │                                  │
│                    ┌─────▼─────┐                            │
│                    │  GHCR     │                            │
│                    │ (publish) │                            │
│                    └───────────┘                            │
└─────────────────────────────────────────────────────────────┘
```

**Уровень 1 — Базовые образы** (`Dockerfile.base.*`): содержат ROS2 Humble, CUDA Toolkit, PCL, Eigen, Livox-SDK2 и инструменты сборки (colcon, cmake). Публикуются в GHCR с тегами `ros2-base-{platform}:latest`.

**Уровень 2 — Пакетные образы** (`Dockerfile.package`): принимает URL репозитория, ветку, имя пакета и архитектуру CUDA через `ARG`. Клонирует исходники, устанавливает зависимости через `rosdep`, собирает через `colcon build` с CUDA-флагами. Результат — runtime-образ с entrypoint.

---

## Платформы и образы

| Платформа | Базовый образ NVIDIA | CUDA Arch | L4T | Ubuntu | ROS2 | Архитектура |
|-----------|---------------------|-----------|-----|--------|------|-------------|
| **x86_64** | `nvidia/cuda:12.9.0-devel-ubuntu22.04` | 86 | N/A | 22.04 | Humble | linux/amd64 |
| **AGX Orin** | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | 87 | R36.4.0 | 22.04 | Humble | linux/arm64 |
| **Orin Nano** | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | 87 | R36.4.0 | 22.04 | Humble | linux/arm64 |

### Обоснование выбора CUDA-архитектур

- **86** (Ampere) — стандарт для современных x86 GPU (RTX 30xx, A4000+).
- **87** (Ampere Orin) — архитектура GPU в Jetson AGX Orin и Jetson Orin Nano. Оба модуля используют GPU на архитектуре Ampere.

> **Важно:** Orin Nano — это не оригинальный Jetson Nano (архитектура Maxwell, CUDA 53). Orin Nano относится к семейству Orin и использует GPU Ampere (CUDA arch 87).

---

## Ограничения и обоснование решений

### 1. L4T R36.4.0 вместо R36.5.0/R36.5.2

ТЗ требует JetPack 6.2.2 (L4T R36.5.0). На момент реализации последний опубликованный Docker-образ `l4t-jetpack` в NGC — **r36.4.0** [web_15_0_0_0]. Версии R36.5.x существуют как пакеты JetPack (6.2.3, L4T R36.5.2), но соответствующий контейнер в NGC не опубликован.

**Решение:** Использовать `r36.4.0` как ближайший доступный образ. L4T R36.4.0 и R36.5.x основаны на одном ядре (5.15.x-tegra) и Ubuntu 22.04 — совместимость на уровне Docker обеспечена.

### 2. JetPack 6.x для Orin Nano вместо JetPack 7

ТЗ упоминает JetPack 7 для Orin Nano. JetPack 7.2.1 (L4T R39.2.1) основан на **Ubuntu 24.04 LTS**, на которой ROS2 Humble **официально не поддерживается** [web_15_0_0_6]. ROS2 Humble требует Ubuntu 22.04 (Jammy).

**Решение:** Использовать JetPack 6.x (L4T R36.4.0, Ubuntu 22.04) для всех ARM-платформ, чтобы сохранить единый стек ROS2 Humble. Альтернативный вариант с JetPack 7 + ROS2 Jazzy доступен в ветке `feature/variant-b-jazzy`.

### 3. QEMU вместо нативной сборки как основной метод

Для кросс-сборки ARM-образов на x86-раннере GitHub Actions используется эмуляция QEMU через `docker/setup-qemu-action`. Сборка через QEMU в 5–10 раз медленнее нативной [web_15_0_0_10], но не требует физических ARM-устройств.

**Решение:** QEMU — основной метод (job `build-packages-qemu`). Нативная сборка доступна как опция через self-hosted раннеры (job `build-packages-native`).

### 4. `SHELL ["/bin/bash", "-c"]` в Dockerfile

Образы `l4t-jetpack` используют `/bin/sh` по умолчанию, в котором недоступна команда `source`. Это вызывало ошибку `exit code: 127: source: not found`.

**Решение:** Добавлена директива `SHELL ["/bin/bash", "-c"]` в `Dockerfile.package`.

### 5. Убран `-std=c++17` из `CMAKE_CUDA_FLAGS`

Передача `-std=c++17` одновременно через `CMAKE_CUDA_FLAGS` и `CMAKE_CUDA_STANDARD=17` вызывала `incompatible redefinition for option 'std'` в nvcc на ARM64.

**Решение:** Стандарт C++17 задаётся только через `CMAKE_CUDA_STANDARD=17`. CMake сам подставляет правильный флаг для nvcc.

### 6. Workaround `ldconfig` для QEMU

В среде QEMU бинарный `ldconfig` архитектуры ARM64 может зависать при установке пакетов через `apt-get`.

**Решение:** В `Dockerfile.base.agx` и `Dockerfile.base.nano` `ldconfig` временно подменяется на заглушку (`exit 0`) перед установкой пакетов и восстанавливается после.

---

## Структура репозитория

```
ros2-cuda-crossbuild/
├── docker/
│   ├── Dockerfile.base.x86          # Базовый образ x86_64 (Humble + CUDA)
│   ├── Dockerfile.base.agx          # Базовый образ AGX Orin (Humble + L4T)
│   ├── Dockerfile.base.nano         # Базовый образ Orin Nano (Humble + L4T)
│   └── Dockerfile.package           # Универсальный шаблон сборки пакета
├── .github/
│   └── workflows/
│       └── build.yml                # CI/CD пайплайн
├── scripts/
│   ├── local-build.sh               # Локальная сборка без GitHub Actions
│   ├── verify-cuda.sh               # Проверка CUDA в собранных образах
│   ├── setup-qemu.sh                # Настройка QEMU на x86-хосте
│   └── add-package.sh               # Помощник добавления нового пакета
└── README.md                         # Документация
```

---

## Развёртывание CI/CD

### Предварительные требования

1. **GitHub репозиторий** с включёнными Actions (Settings → Actions → General → Allow all actions).
2. **Secret `GHCR_PAT`** — Personal Access Token с правами `write:packages` (Settings → Secrets and variables → Actions → New repository secret).
3. Docker с поддержкой Buildx на локальной машине (для локальной сборки).

### Шаги развёртывания

1. Клонируйте репозиторий и перейдите в ветку Варианта A:
   ```bash
   git clone https://github.com/MindMaze74/ros2-cuda-crossbuild.git
   cd ros2-cuda-crossbuild
   git checkout feature/variant-a-humble
   ```

2. Убедитесь, что secret `GHCR_PAT` добавлен в настройки репозитория.

3. Запустите пайплайн:
   - **Автоматически:** push в `main` или создание тега `v*` запустит пайплайн.
   - **Вручную:** Actions → CI/CD Pipeline → Run workflow.

4. При первом запуске выберите `build_base: true` для создания базовых образов.

### Триггеры пайплайна

| Событие | Условие | Действие |
|---------|---------|---------|
| `push` | Ветка `main` или `feature/**` | Сборка пакетов |
| `push` | Тег `v*` | Сборка пакетов + публикация |
| `workflow_dispatch` | Ручной запуск | Выборочная сборка |

### Параметры ручного запуска (`workflow_dispatch`)

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `build_base` | Пересобрать базовые образы | `false` |
| `build_packages` | Пересобрать пакетные образы | `true` |
| `platform` | Целевая платформа (`x86`, `agx`, `nano`, пусто = все) | `""` |
| `build_type` | Тип сборки (`qemu`, `native`, `all`) | `qemu` |

---

## Добавление нового пакета

### Способ 1: Через скрипт-помощник

```bash
./scripts/add-package.sh
```

Скрипт запросит имя пакета, URL репозитория и ветку, затем выведет готовые фрагменты для вставки в `build.yml`.

### Способ 2: Вручную

В `.github/workflows/build.yml` найдите секцию `build-packages-qemu` → `matrix.include` и добавьте три записи:

```yaml
- package: my_new_package
  platform: x86
  target_platform: linux/amd64
  cuda_arch: "86"
- package: my_new_package
  platform: agx
  target_platform: linux/arm64
  cuda_arch: "87"
- package: my_new_package
  platform: nano
  target_platform: linux/arm64
  cuda_arch: "87"
```

Затем в `build-args` укажите:

```yaml
build-args: |
  BASE_IMAGE=${{ env.REGISTRY }}/${{ steps.repo.outputs.NAME }}/ros2-base-


