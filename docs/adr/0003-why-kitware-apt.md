# 0003. CMake из Kitware APT вместо apt/pip

## Контекст

Пакеты FAST-LIO2 и FAST-LIVO2 требуют `CMAKE_CUDA_STANDARD=17` при сборке
CUDA-кода. На Ubuntu 22.04 системный CMake — 3.22. На Ubuntu 24.04 — 3.28.

## Проблема

CMake 3.22 **не пробрасывает** значение `CMAKE_CUDA_STANDARD` в `nvcc`.
Это известное ограничение: свойство `CUDA_STANDARD` игнорируется на CUDA-таргетах
до CMake 3.24. В результате `nvcc` собирает без `-std=c++17`, что ломает
заголовки CUDA 12.x, требующие C++17.

Симптом: ошибки вида `#error C++17 required` или несовместимость с libstdc++.

## Рассматриваемые варианты

1. **`pip3 install cmake` на Ubuntu 22.04.**
   Плюсы: быстро, одна команда.
   Минусы: на Ubuntu 24.04 PEP 668 запрещает `pip3 install` без
   `--break-system-packages` — небезопасно, ломает system Python.

2. **`apt install cmake` из стандартных репозиториев.**
   Минусы: даёт 3.22 на 22.04 — не решает проблему.

3. **Kitware APT репозиторий.**
   Официально поддерживаемый Kitware источник, аналог `apt.llvm.org`.
   Даёт CMake 3.29+ (сейчас 4.4.3) на обеих платформах.

4. **Собрать CMake из исходников.**
   Минусы: долго (10+ минут на ARM под QEMU), не нужно при наличии APT.

## Решение

**Kitware APT** (вариант 3). Единый подход для Ubuntu 22.04 и 24.04.

Установка в `Dockerfile.base.*`:

```dockerfile
RUN apt-get update && apt-get install -y wget gpg && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
      | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] \
      https://apt.kitware.com/ubuntu/ $(lsb_release -cs) main" \
      > /etc/apt/sources.list.d/kitware.list && \
    apt-get update && apt-get install -y cmake && \
    rm -rf /var/lib/apt/lists/*