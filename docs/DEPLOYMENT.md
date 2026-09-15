# Инструкция по развёртыванию

## Требования

- GitHub репозиторий с Actions включёнными
- Права на push в GHCR (Settings → Actions → Read and write permissions)

## Первоначальная настройка

1. Клонировать репозиторий
2. Настроить GitHub Actions: Settings → Actions → General → Workflow permissions → **Read and write permissions**
3. Запустить **Build Base Images** (Actions → Run workflow с build_base=true)
4. Дождаться завершения базовых образов
5. Запустить **Build Packages** (Actions → Run workflow)

## Добавление нового пакета

1. Добавить запись в `config/packages.yaml`:
   ```yaml
   - name: my_package
     repo: https://github.com/org/my_package.git
     branch: main
     package_name: my_package
     ros_distro: humble
     cuda_arch: { x86: "86", agx: "87", nano: "87" }
     cmake_args: "-DCMAKE_BUILD_TYPE=Release"

2. Закоммитить и запушить

3. CI автоматически соберёт образ

## Использование образов

```bash
docker pull ghcr.io/OWNER/ros2-cuda-crossbuild/ros2-package-fastlio2:x86
docker run --gpus all -it --rm ghcr.io/OWNER/ros2-cuda-crossbuild/ros2-package-fastlio2:x86
```

## Платформы и JetPack

Платформа  	ОС	       Base           image
x86	      Ubuntu       22.04	        nvidia/cuda:12.9.0
agx	      Ubuntu       22.04	        nvcr.io/nvidia/l4t-jetpack:r36.4.0
nano	    Ubuntu       24.04	        nvidia/cuda:12.6.3

> Примечание: официального образа l4t-jetpack:r36.5.0 (JetPack 6.2.2) в NGC нет. Используется r36.4.0  совместим по ключевым библиотекам CUDA.

