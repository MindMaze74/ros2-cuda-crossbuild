# Развёртывание

Инструкция по развёртыванию пайплайна, добавлению новых пакетов
и подключению self-hosted Jetson-раннеров.

---

## Требования

- Аккаунт GitHub с правом создавать Actions и пакеты в GHCR.
- Локально: `git`, `docker` 24+, `gh` CLI (для ручных операций).
- Для native-ARM: физический Jetson AGX Orin или Orin Nano с сетевым доступом к GitHub.

---

## 1. Развёртывание пайплайна

### 1.1 Клон репозитория

```bash
git clone git@github.com:MindMaze74/ros2-cuda-crossbuild.git
cd ros2-cuda-crossbuild
```

### 1.2 Проверка настроек репозитория

**Settings → Actions → General → Workflow permissions:**

- **Read and write permissions** — включено.
- **Allow GitHub Actions to create and approve pull requests** — включено.

**Секреты не нужны.** `GITHUB_TOKEN` со скоупом `packages: write` достаточен
для пуша в GHCR. PAT (`GHCR_PAT`) не требуется.

### 1.3 Первый прогон

**Actions → CI/CD Pipeline → Run workflow:**

| Поле | Значение |
|---|---|
| Branch | `main` |
| Rebuild base images | true (первый раз) |
| Rebuild package images | true |
| Build native ARM | ☐ false (нет раннера) |
| Package | `all` |
| Platform | пусто |

Ожидаемое время: **4–5 часов** (первый прогон без кеша).
Повторные прогоны: **1.5–2 часа**.

### 1.4 Проверка результата

```bash
docker pull ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest
docker run --rm ghcr.io/mindmaze74/ros2-cuda-crossbuild/ros2-base-x86:latest nvcc --version
```

Ожидаемый вывод — версия CUDA Toolkit (`Cuda compilation tools, release 12.x`).

---

## 2. Добавление нового пакета

Один шаг — правка `config/packages.yaml`.

### 2.1 Пример записи

```yaml
packages:
  - name: my_package
    repo: https://github.com/org/my_package.git
    branch: main
    package_name: my_package
    ros_distro:
      x86: humble
      agx: humble
      nano: jazzy
    cuda_arch:
      x86: "86"
      agx: "87"
      nano: "87"
    cmake_args: "-DCMAKE_BUILD_TYPE=Release"
    # platforms: [x86, agx]   # если пакет не собирается на какой-то платформе
```

### 2.2 Обновить список в workflow (опционально)

Для фильтра по имени при ручном запуске — правка
`.github/workflows/build.yml`, секция `workflow_dispatch.inputs.package.options`:

```yaml
      package:
        description: 'Package'
        type: choice
        options:
          - all
          - fastlio2
          - fastlivo2
          - my_package   # ← добавить
        default: all
```

### 2.3 Дополнительные зависимости (если нужны)

Правка `docker/Dockerfile.package` — добавить условный `RUN`:

```dockerfile
RUN if [ "$PACKAGE_NAME" = "my_package" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        ros-${ROS_DISTRO}-some-dep \
      && rm -rf /var/lib/apt/lists/*; \
    fi
```

### 2.4 Коммит

```bash
git add config/packages.yaml .github/workflows/build.yml docker/Dockerfile.package
git commit -m "feat: add my_package"
git push origin main
```

Workflow запустится автоматически по триггеру `paths: config/**`.

---

## 3. Self-hosted runner на Jetson

Раздел для native-ARM сборки (закрывает п. 3.4 ТЗ).

### 3.1 Требования

- Jetson AGX Orin или Orin Nano.
- Ubuntu 22.04 (AGX) или 24.04 (Nano).
- Docker 24+ с NVIDIA Container Toolkit.
- Сетевой доступ к GitHub (исходящий HTTPS, 443).
- ~50 ГБ свободного места на диске.

### 3.2 Установка Docker + NVIDIA runtime

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

sudo apt update && sudo apt install -y nvidia-container-toolkit
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Проверка
docker run --rm --runtime=nvidia nvidia/cuda:12.6.3-base-ubuntu22.04 nvidia-smi
```

### 3.3 Подключение runner'а

На GitHub: **Settings → Actions → Runners → New self-hosted runner**.
Выберите Linux / ARM64.

На Jetson:

```bash
mkdir -p ~/actions-runner && cd ~/actions-runner
# Команды скачивания — из GitHub UI
./config.sh \
  --url https://github.com/MindMaze74/ros2-cuda-crossbuild \
  --token <TOKEN_ИЗ_UI> \
  --name "jetson-agx" \
  --labels "self-hosted,arm64,jetson-agx" \
  --work "_work" \
  --unattended
```

**Метки критичны:**

- Для AGX: `self-hosted,arm64,jetson-agx`
- Для Nano: `self-hosted,arm64,jetson-nano`

Workflow выбирает runner по этим меткам. Если метки другие — job уйдёт
в очередь и упадёт по `timeout-minutes`.

### 3.4 Запуск как сервис

```bash
sudo ./svc.sh install $USER
sudo ./svc.sh start
sudo ./svc.sh status
```

### 3.5 Проверка

**Actions → CI/CD Pipeline → Run workflow:**

| Поле | Значение |
|---|---|
| Build native ARM | true |
| Package | `fastlio2` |
| Platform | `agx` |

Ожидаемо: `setup` сгенерирует **7 записей**, `build-packages` соберёт
native-ARM за ~10–15 минут. Результат: `ros2-package-fastlio2:agx-native`.

### 3.6 Обслуживание

**Раз в неделю:**

```bash
docker system prune -af
docker builder prune -af
```

**Раз в месяц — обновление runner'а:**

```bash
cd ~/actions-runner
./config.sh remove --token <TOKEN>
# Затем скачать свежую версию и заново ./config.sh
```

---

## 4. Обновление базовых образов

1. Правка `build-base.matrix` в `.github/workflows/build.yml` — поле `base_image`.
2. Правка `docker/Dockerfile.base.*` — если меняется структура.
3. **Actions → Run workflow** с `build_base: true`.
4. После успеха — `build_packages: true` (запинится новый digest).

**Внимание:** при смене базового образа digest изменится, все пакеты
пересоберутся с нуля. Кеш `type=registry` не поможет — слои другие.

---

## 5. Удаление старых пакетов из GHCR

```bash
gh auth refresh -h github.com -s read:packages,delete:packages

gh api --paginate '/user/packages?package_type=container' --jq '.[].name' \
  | grep '^ros2-cuda-crossbuild/' \
  | while read -r pkg; do
      encoded=$(printf '%s' "$pkg" | jq -sRr @uri)
      echo "Deleting: $pkg"
      gh api --method DELETE "/user/packages/container/${encoded}"
    done
```

---

## 6. Диагностика

| Симптом | Причина | Решение |
|---|---|---|
| `permission_denied: read_package` | Осиротевший пакет в GHCR | Удалить пакет (раздел 5), добавить `LABEL org.opencontainers.image.source` |
| `base name (${BASE_IMAGE}) should not be blank` | Не передан `build-args: BASE_IMAGE=...` | Проверить step `docker/build-push-action` |
| `Could NOT find PythonLibs` | Нет `python3-dev` в builder | Добавить в `Dockerfile.package` |
| `source /opt/ros/humble/setup.bash: No such file` | `ROS_DISTRO` не совпадает с базой | Проверить `ros_distro` в `packages.yaml` (map по платформам) |
| `QEMU segfault на ldconfig` | Известная проблема QEMU на ARM | Заглушка `ldconfig` в базовом Dockerfile |
| Native-ARM job висит в очереди | Нет runner'а с нужными метками | Подключить runner (раздел 3) или `build_native_arm: false` |
| `InvalidDefaultArgInFrom` warning | `ARG BASE_IMAGE` без дефолта | Игнорировать, это предупреждение |
| `chore/readme-sync` PR не создаётся | Actions не может создать PR | Settings → Actions → General → Workflow permissions → **Read and write** + **Allow GitHub Actions to create and approve pull requests** |

---

## 7. Ссылки

- **Actions:** https://github.com/MindMaze74/ros2-cuda-crossbuild/actions
- **Packages:** https://github.com/MindMaze74?tab=packages
- **Issues:** https://github.com/MindMaze74/ros2-cuda-crossbuild/issues
