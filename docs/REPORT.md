# Отчёт по практической работе

**Проект:** Система автоматической кросс-платформенной сборки Docker-образов
для ROS2-пакетов с CUDA

**Репозиторий:** https://github.com/MindMaze74/ros2-cuda-crossbuild

---

## 1. Назначение и область применения

Разработана система автоматической кросс-платформенной сборки Docker-образов
для ROS2-пакетов, использующих CUDA. Система собирает образы под три целевые
платформы:

- **x86_64** с NVIDIA GPU (Ampere, sm_86);
- **ARM64 / Jetson AGX Orin 64GB** (JetPack 6.2.2, L4T R36.5.0, sm_87);
- **ARM64 / Jetson Orin Nano** (JetPack 7, Ubuntu 24.04, sm_87).

Сборка выполняется двумя способами:

1. **Кросс-платформенно** — ARM64-образы собираются на x86-раннере
   через QEMU-эмуляцию (`docker/setup-qemu-action`, `docker/buildx`).
2. **Нативно** — ARM64-образы собираются на self-hosted Jetson-раннере,
   подключённом к GitHub Actions. Активируется флагом `build_native_arm`
   при ручном запуске.

Все собираемые библиотеки имеют поддержку CUDA, подтверждённую smoke-тестом
компиляции и запуском CUDA-кода в runtime-контейнере.

---

## 2. Цель работы

Настроен рабочий CI/CD-пайплайн, который:

- **Автоматически собирает** Docker-образы для трёх платформ;
- **Включает CUDA Toolkit** в каждый образ (проверено `nvcc --version` и
  smoke-компиляцией);
- **Позволяет добавлять новые пакеты** одной записью в `config/packages.yaml`;
- **Публикует образы** в GitHub Container Registry (`ghcr.io`).

---

## 3. Реализация задач

### 3.1 Исследование и подготовка

**Архитектурные различия платформ:**

| Параметр | x86_64 | Jetson AGX Orin | Jetson Orin Nano |
|---|---|---|---|
| Архитектура | amd64 | arm64 (aarch64) | arm64 (aarch64) |
| Базовый образ | `nvidia/cuda:12.9.0-devel-ubuntu22.04` | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | `nvidia/cuda:12.6.3-devel-ubuntu24.04` |
| OS | Ubuntu 22.04 | Ubuntu 22.04 | Ubuntu 24.04 |
| ROS2 | Humble | Humble | Jazzy (см. ADR-0002) |
| CUDA arch | 86 | 87 | 87 |
| Особенности | стандартный CUDA-стек | L4T, `r36.4.0` вместо `r36.5.0` (нет в NGC) | JetPack 7, PEP 668 |

**Инструменты:** Docker Buildx, QEMU (ARM64-эмуляция), официальные контейнеры
NVIDIA (`nvcr.io/nvidia/l4t-jetpack`), CMake 4.4.3 из официального бинарного
архива Kitware на GitHub.

**Тестовый пакет:** FAST-LIO2 в модификации `ruiqichao/FAST_LIO2_GPU`
(содержит CUDA-версию `ikd-Tree`). Репозиторий `hku-mars/FAST_LIVO2`
не используется: это ROS1 catkin-пакет, несовместимый с ROS2 ament-сборкой
(`find_package(catkin REQUIRED)` в `CMakeLists.txt`). ТЗ допускает любой
из двух тестовых пакетов.

### 3.2 Базовые Docker-образы

Три образа собраны и опубликованы в GHCR:

| Образ | Тег |
|---|---|
| x86 base | `ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest` |
| AGX base | `ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-agx:latest` |
| Nano base | `ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-nano:latest` |

Все содержат ROS2, CUDA Toolkit, `colcon`, `rosdep`. CMake 4.4.3 доставляется
в `Dockerfile.package` из официального бинарного архива GitHub
(`github.com/Kitware/CMake/releases`) — системный CMake 3.22 из Ubuntu 22.04
не пробрасывает `CMAKE_CUDA_STANDARD=17` в `nvcc` (см. ADR-0003).

Образы запинены по digest — `build-packages` резолвит digest базового образа
на лету и использует `@sha256:...` вместо мутабельного `:latest`.

**Отклонение от ТЗ:** Nano использует ROS2 Jazzy вместо Humble. Обоснование
см. `docs/adr/0002-why-jazzy-for-nano.md`. Причина: JetPack 7 работает
только на Ubuntu 24.04, а Humble для 24.04 не поддерживается upstream.

### 3.3 Универсальный шаблон сборки

`docker/Dockerfile.package` — multi-stage шаблон. Принимает аргументы:

- `BASE_IMAGE` — базовый образ (`ros2-base-<platform>:latest`);
- `CUDA_ARCHITECTURES` — 86 для x86, 87 для Orin;
- `REPO_URL`, `BRANCH` — репозиторий и ветка собираемого пакета;
- `PACKAGE_NAME` — имя пакета для `colcon --packages-select`;
- `ROS_DISTRO` — humble или jazzy;
- `CMAKE_ARGS` — дополнительные флаги CMake.

Особенности:

- CMake 4.4.3 из бинарного архива GitHub — обход нестабильного apt-репозитория
  Kitware (`apt.kitware.com` периодически недоступен в CI). Архитектура
  (`x86_64` / `aarch64`) определяется автоматически через `uname -m`, что
  позволяет использовать один Dockerfile для всех трёх платформ;
- временное отключение CUDA-репозитория NVIDIA в builder — обход
  рассинхронизации `Packages.gz` (`File has unexpected size`). CUDA уже
  установлена в базовом образе, переустановка не нужна;
- `python3-dev` + `libpython3-dev` — для `find_package(PythonLibs REQUIRED)`,
  которое делает `FAST_LIO2_GPU`;
- `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` — обход CMake 4.x на старых
  `cmake_minimum_required` в исследовательских CMakeLists;
- smoke-проверки `nvcc --version` и наличие `install/setup.bash`.

Блок Sophus + Vikit для `fast_livo` сохранён в Dockerfile с условием
`[ "$PACKAGE_NAME" = "fast_livo" ]` как документированная заготовка на случай
появления ROS2-совместимого форка FAST-LIVO2. Для FAST-LIO2 блок инертен.

### 3.4 Кросс-платформенная сборка

Реализованы **два способа** сборки ARM64:

1. **Кросс через QEMU** — `ubuntu-latest` + `docker/setup-qemu-action`.
   Работает без дополнительной инфраструктуры. Медленно (× 5–20 от нативной).
   Обход segfault на `ldconfig` — заглушка в базовых Dockerfile'ах.
2. **Нативно на self-hosted Jetson-раннере** — включается флагом
   `build_native_arm` при ручном запуске workflow. Раннеры маркируются
   тегами `[self-hosted, arm64, jetson-agx]` и `[self-hosted, arm64, jetson-nano]`.
   Результаты пушатся в отдельный тег `:agx-native` / `:nano-native`,
   чтобы не перетирать cross-сборки.

Инструкция по подключению self-hosted runner'а — `docs/DEPLOYMENT.md`,
раздел 3.

### 3.5 Автоматизация CI/CD

**Триггеры:**

- Push в `main` и `feature/**` при изменении `docker/**`, `config/**`,
  `.github/workflows/build.yml`;
- Tags `v*`;
- Ручной запуск `workflow_dispatch` с inputs: `build_base`, `build_packages`,
  `build_native_arm`, `package`, `platform`.

**Матричная сборка:**

| Job | Матрица | Параллелизм |
|---|---|---|
| `build-base` | 3 платформы | `max-parallel: 1` |
| `build-packages` | 3 cross + 2 native (по флагу) = 3–5 | `max-parallel: 1` |
| `test-images` | те же 3–5 | `max-parallel: 3` |

Формально ТЗ требует «3 платформы × 2 типа сборки = 6 комбинаций».
Реализовано 3 cross-комбинации (x86 / agx / nano) для FAST-LIO2 плюс
2 native-комбинации (agx-native, nano-native) — включаются флагом
при наличии self-hosted Jetson-раннеров.

**Кеширование:**

- Registry cache: `type=registry,mode=max` — переживает между прогонами;
- Local BuildKit cache через `actions/cache` — быстрее, но привязан к runner'у;
- Оба используются одновременно (`cache-from: [local, registry]`).

**Тестирование образов** (`test-images`):

1. `nvcc --version` — CUDA Toolkit присутствует;
2. Smoke-компиляция CUDA-программы + запуск — проверка не только наличия
   `nvcc`, но и работоспособности компиляции и линковки с `libcudart`;
3. `source /opt/ros/${ROS_DISTRO}/setup.bash` — дистрибутив ROS2 совпадает;
4. Проверка наличия `install/setup.bash`;
5. `ldd` по всем бинарникам — поиск потерянных разделяемых библиотек;
6. `ros2 pkg list | grep <package>` — пакет виден ROS2.

**Дополнительно:**

- `concurrency` — отмена устаревших прогонов при новом пуше в ту же ветку;
- `timeout-minutes` — защита от зависаний QEMU и native-ARM без раннера;
- `permissions` на уровне job'ов — least privilege;
- digest-пиннинг базовых образов — воспроизводимость;
- автогенерация README (`README Sync`) — таблица поддерживаемых пакетов
  из `packages.yaml`.

### 3.6 Документирование

| Документ | Содержание |
|---|---|
| `README.md` | Быстрый старт, автогенерируемая таблица пакетов |
| `docs/DEPLOYMENT.md` | Развёртывание, добавление пакета, self-hosted runner |
| `docs/architecture.md` | Схема пайплайна (Mermaid), поток данных, кеширование |
| `docs/REPORT.md` | Этот документ |
| `docs/adr/0001-why-qemu.md` | Обоснование QEMU вместо только native ARM |
| `docs/adr/0002-why-jazzy-for-nano.md` | Обоснование Jazzy на Nano |
| `docs/adr/0003-why-kitware-apt.md` | Обоснование CMake из бинарного архива |
| `scripts/render-readme.sh` | Генерация таблицы пакетов |

---

## 4. Ожидаемые результаты

| Пункт ТЗ | Статус | Где смотреть |
|---|---|---|
| Работающий CI/CD-пайплайн | ✅ | `.github/workflows/build.yml`, вкладка Actions |
| Три базовых Docker-образа в реестре | ✅ | `ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-*` |
| Пример собранного образа FAST-LIO2 | ✅ | `ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-package-fastlio2:*` |
| Подтверждение наличия CUDA | ✅ | Лог job'а `test-images`, шаг `Pull and test image` |
| Документация и вспомогательные скрипты | ✅ | `docs/`, `scripts/` |

**Публичные ссылки:**

- Actions: https://github.com/MindMaze74/ros2-cuda-crossbuild/actions
- Образы: https://github.com/MindMaze74?tab=packages

---

## 5. Принятые решения

См. `docs/adr/`:

- [ADR-0001](adr/0001-why-qemu.md) — почему QEMU, а не только native ARM;
- [ADR-0002](adr/0002-why-jazzy-for-nano.md) — почему Jazzy на Nano;
- [ADR-0003](adr/0003-why-kitware-apt.md) — почему CMake из бинарного архива.

---

## 6. Отклонения от ТЗ

| Пункт ТЗ | Отклонение | Обоснование |
|---|---|---|
| 3.1: «FAST-LIO2 **или** FAST-LIVO2» | Используется FAST-LIO2 | FAST-LIVO2 — ROS1 catkin-пакет, несовместимый с ROS2 ament (`find_package(catkin REQUIRED)`). ТЗ допускает любой из двух |
| 3.2: «ROS2 Humble» для всех платформ | Nano использует Jazzy | JetPack 7 требует Ubuntu 24.04; Humble для 24.04 не поддерживается upstream |
| 3.2: `l4t-jetpack:r36.5.0` | Используется `r36.4.0` | Образ `r36.5.0` отсутствует в NGC на момент разработки |
| 3.5: «3 платформы × 2 типа сборки» | 3 cross + 2 native (по флагу) | Native-ARM требует физического Jetson-раннера; архитектурно реализовано, включается флагом |
| 3.5: native AGX и native Nano | Опциональны по ТЗ | Требуют self-hosted runner'а; инструкция приложена |

---

## 7. Выводы

- Пайплайн работает на стандартных `ubuntu-latest` без дополнительной
  инфраструктуры. Кросс-сборка ARM64 через QEMU решает задачу без железа.
- Образы воспроизводимы: базовые пинятся по digest, `packages.yaml` —
  единственный источник конфигурации пакетов.
- Добавление нового пакета — одна запись в `config/packages.yaml`.
- Кеширование сокращает повторные прогоны с ~3 часов до ~1.5–2 часов.
- Тестовый пакет FAST-LIO2 (`ruiqichao/FAST_LIO2_GPU`) собирается на всех
  трёх платформах с поддержкой CUDA. FAST-LIVO2 не используется, так как
  опубликован только под ROS1 catkin — вопрос зафиксирован в разделе
  «Отклонения», инфраструктура для его сборки подготовлена в Dockerfile.
- Ограничения: QEMU-сборка ARM медленная; для production рекомендуется
  self-hosted Jetson-раннер (инструкция приложена).

---
