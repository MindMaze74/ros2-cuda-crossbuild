```markdown
# Архитектура системы

## Обзор

Система автоматической кросс-платформенной сборки Docker-образов для ROS2-пакетов
с CUDA. Три целевые платформы, единый CI/CD-пайплайн в GitHub Actions.

## Схема пайплайна

```mermaid
flowchart TB
    Trigger[git push / workflow_dispatch] --> Setup[setup<br/>генерация матрицы]
    Trigger --> BuildBase[build-base<br/>3 платформы]

    BuildBase --> x86base[ros2-base-x86<br/>nvidia/cuda:12.9]
    BuildBase --> agxbase[ros2-base-agx<br/>l4t-jetpack:r36.4.0]
    BuildBase --> nanobase[ros2-base-nano<br/>nvidia/cuda:12.6.3]

    x86base -->|digest| PkgX86[build-packages<br/>x86]
    agxbase -->|digest| PkgAgx[build-packages<br/>agx]
    nanobase -->|digest| PkgNano[build-packages<br/>nano]

    Setup --> PkgX86
    Setup --> PkgAgx
    Setup --> PkgNano

    PkgX86 --> TestX86[test-images<br/>x86]
    PkgAgx --> TestAgx[test-images<br/>agx]
    PkgNano --> TestNano[test-images<br/>nano]

    TestX86 --> Done[ghcr.io<br/>готовые образы]
    TestAgx --> Done
    TestNano --> Done
```


```mermaid
sequenceDiagram
    participant Dev as Разработчик
    participant GH as GitHub Actions
    participant Reg as ghcr.io
    participant Runner as Ubuntu Runner + QEMU

    Dev->>GH: git push feature/main-b
    GH->>Runner: build-base (x86/agx/nano)
    Runner->>Reg: push ros2-base-*:latest
    GH->>Runner: build-packages (fastlio2 × 3)
    Note over Runner: BASE_IMAGE=ros2-base-x86@sha256:...
    Runner->>Reg: push ros2-package-fastlio2:x86
    GH->>Runner: test-images (nvcc + ROS2 + ldd)
    Runner-->>GH: OK
    GH-->>Dev: 10 зелёных job'ов

```



| Платформа | База | ROS2 | CUDA arch | Runner | Эмуляция |
| --- | --- | --- | --- | --- | --- |
| x86 | `nvidia/cuda:12.9.0-devel-ubuntu22.04` | Humble | 86 | `ubuntu-latest` | нет |
| agx | `nvcr.io/nvidia/l4t-jetpack:r36.4.0` | Humble | 87 | `ubuntu-latest` | QEMU |
| nano | `nvidia/cuda:12.6.3-devel-ubuntu24.04` | Jazzy | 87 | `ubuntu-latest` | QEMU |



### Кеширование
## Двухуровневое:

1. Registry cache (type=registry,mode=max) — переживает между прогонами,
шарится между ветками, но тянется по сети.

2. Local BuildKit cache через actions/cache — быстрее, но привязан
к конкретному runner'у.

Оба используются одновременно: cache-from: [local, registry],
cache-to: [local, registry]. Это даёт максимальный hit rate.

### Воспроизводимость

build-packages использует digest базового образа, а не мутабельный :latest.
Digest резолвится на лету через docker buildx imagetools inspect перед сборкой.
Это гарантирует, что пакет собран именно из той базовой версии, которая
существует на момент запуска, и не «уедет» при перезаписи :latest.

### Принятые решения
См. docs/adr/:

0001 — почему QEMU, а не нативный ARM-runner

0002 — почему Jazzy на Nano

0003 — почему CMake из Kitware APT