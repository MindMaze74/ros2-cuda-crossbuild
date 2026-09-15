# 0004. CMake из бинарного архива GitHub

## Статус

Accepted. Supersedes [ADR-0003](0003-why-kitware-apt.md).

## Контекст

Пакеты FAST-LIO2 требуют `CMAKE_CUDA_STANDARD=17` при сборке CUDA-кода.
Системный CMake 3.22 из Ubuntu 22.04 не пробрасывает `CMAKE_CUDA_STANDARD`
в `nvcc` — свойство `CUDA_STANDARD` игнорируется на CUDA-таргетах до
CMake 3.24. Нужен CMake 3.28+.

Изначально (ADR-0003) использовался репозиторий `apt.kitware.com`. Решение
работало локально, но в CI регулярно падало:

- `wget https://apt.kitware.com/keys/kitware-archive-latest.asc` возвращал
  пустой ответ → `gpg: no valid OpenPGP data found` → сборка падала с exit 2.
- Транзиентные 5xx и таймауты при `apt-get update` из kitware.list.
- Репозиторий ведёт себя нестабильно именно в CI-окружениях (это признают
  сами мейнтейнеры Kitware — источник предназначен для локальных машин
  разработчиков).

## Рассматриваемые варианты

1. **Оставить Kitware APT + `--tries=5 --waitretry=5`.**
   Плюсы: минимальная правка.
   Минусы: не решает первопричину — `apt.kitware.com` недоступен
   с вероятностью ~30% на прогон. Ретраи только уменьшают частоту, не
   устраняют.

2. **Pip `cmake` пакет.**
   Плюсы: официальный PyPI-пакет от Kitware с бинарником CMake.
   Минусы: на Ubuntu 24.04 (Nano) PEP 668 запрещает `pip3 install`
   без `--break-system-packages`. Ставить в venv — дополнительный слой.

3. **Собрать CMake из исходников.**
   Минусы: 10+ минут на ARM под QEMU, дублирует работу.

4. **Бинарный архив с GitHub Releases.**
   `https://github.com/Kitware/CMake/releases/download/vX.Y.Z/cmake-X.Y.Z-linux-{x86_64,aarch64}.tar.gz`
   Плюсы: GitHub Releases стабилен, 99.9% uptime. Архитектура покрывается
   одним выражением `uname -m`. Скачивание и распаковка — 5 секунд.
   Минусы: образ растёт на ~200 МБ (распакованный CMake). Не критично —
   builder-stage всё равно отбрасывается, в runtime ничего не попадает.

## Решение

**Бинарный архив с GitHub** (вариант 4). CMake 4.4.3 устанавливается
в `/opt/cmake`, симлинки в `/usr/local/bin/cmake` (раньше системного
`/usr/bin/cmake`).

Код в `docker/Dockerfile.package`:

```dockerfile
ARG CMAKE_VERSION=4.4.3
RUN set -eux; \
    ARCH=$(uname -m); \
    wget --tries=5 --waitretry=5 --timeout=120 \
        -O /tmp/cmake.tar.gz \
        "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-${ARCH}.tar.gz"; \
    test -s /tmp/cmake.tar.gz; \
    mkdir -p /opt/cmake; \
    tar -xzf /tmp/cmake.tar.gz -C /opt/cmake --strip-components=1; \
    rm -f /tmp/cmake.tar.gz; \
    ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake; \
    ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest; \
    ln -sf /opt/cmake/bin/cpack /usr/local/bin/cpack; \
    cmake --version; \
    cmake --version | grep -qE 'version (3\.2[89]|[4-9])'
```

## Последствия

- `CMAKE_CUDA_STANDARD=17` работает на всех трёх платформах.
- Единый Dockerfile для x86_64 и aarch64 — архитектура через `uname -m`.
- Независимость от внешнего APT-репозитория — нет точек отказа
  вида «apt.kitware.com сегодня недоступен».
- Образ builder растёт на ~200 МБ. Для runtime не важно: бинарник CMake
  не копируется во второй stage.
- Версия CMake пинится через `ARG CMAKE_VERSION=4.4.3` — обновление
  контролируемое.

## Ссылки

- ADR-0003 (предыдущее решение, superseded) — [0003-why-kitware-apt.md](0003-why-kitware-apt.md)
- GitHub Releases CMake — https://github.com/Kitware/CMake/releases
