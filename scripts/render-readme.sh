#!/usr/bin/env bash
#
# Генерация секции "Поддерживаемые пакеты" в README.md из config/packages.yaml.
#
# Секция ограничена маркерами:
#   <!-- PACKAGES_TABLE:START -->
#   <!-- PACKAGES_TABLE:END -->
#
# Всё, что вне маркеров, не трогается.
#
# Реализация: Python3 + PyYAML. Это даёт одинаковое поведение локально и в CI,
# не требует установки yq (у которого на разных платформах разные версии
# с несовместимым синтаксисом), и не зависит от того, как GitHub-раннер
# кладёт бинарники в $PATH.
#
# Зависимости: python3, PyYAML (pip install pyyaml).

set -euo pipefail

PACKAGES_YAML="${1:-config/packages.yaml}"
README="${2:-README.md}"

if [ ! -f "$PACKAGES_YAML" ]; then
  echo "ERROR: $PACKAGES_YAML not found" >&2
  exit 1
fi

if [ ! -f "$README" ]; then
  echo "ERROR: $README not found" >&2
  exit 1
fi

# Проверка зависимостей.
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 не найден." >&2
  exit 1
fi

if ! python3 -c "import yaml" >/dev/null 2>&1; then
  echo "ERROR: PyYAML не установлен. Установите: pip3 install --user pyyaml" >&2
  echo "       Или системно: sudo apt install python3-yaml" >&2
  exit 1
fi

SECTION_FILE=$(mktemp)
trap 'rm -f "$SECTION_FILE"' EXIT

python3 - "$PACKAGES_YAML" "$SECTION_FILE" <<'PYEOF'
import sys
import yaml

yaml_path, out_path = sys.argv[1], sys.argv[2]

with open(yaml_path) as f:
    data = yaml.safe_load(f)

packages = data.get("packages", [])
count = len(packages)

lines = []
lines.append("<!-- PACKAGES_TABLE:START -->")
lines.append("<!-- Секция сгенерирована автоматически из config/packages.yaml. -->")
lines.append("<!-- Не редактируйте вручную — правьте packages.yaml. -->")
lines.append("")
lines.append("## Поддерживаемые пакеты")
lines.append("")
lines.append(
    f"Всего пакетов: **{count}**. "
    "Матрица: пакет × 3 платформы (x86 / agx / nano)."
)
lines.append("")
lines.append("| Пакет | Репозиторий | Ветка | ROS2 | x86 | agx | nano |")
lines.append("|---|---|---|---|---|---|---|")

for pkg in packages:
    name = pkg.get("name", "")
    repo = pkg.get("repo", "")
    branch = pkg.get("branch", "")

    ros = pkg.get("ros_distro", "")
    if isinstance(ros, dict):
        # Разные дистрибутивы для разных платформ.
        # Показываем через слэш: humble/humble/jazzy.
        ros_str = "{}/{}/{}".format(
            ros.get("x86", "—"),
            ros.get("agx", "—"),
            ros.get("nano", "—"),
        )
    else:
        ros_str = str(ros) if ros else "—"

    arch = pkg.get("cuda_arch", {}) or {}
    ax = arch.get("x86", "—")
    ag = arch.get("agx", "—")
    an = arch.get("nano", "—")

    short_repo = repo.replace("https://github.com/", "").replace(".git", "")

    lines.append(
        f"| `{name}` | [{short_repo}]({repo}) | `{branch}` | "
        f"`{ros_str}` | `{ax}` | `{ag}` | `{an}` |"
    )

lines.append("")
lines.append(
    "Добавление нового пакета — одна запись в "
    "[`config/packages.yaml`](config/packages.yaml)."
)
lines.append("После пуша workflow `README Sync` автоматически обновит эту таблицу.")
lines.append("")
lines.append("<!-- PACKAGES_TABLE:END -->")

with open(out_path, "w") as f:
    f.write("\n".join(lines) + "\n")
PYEOF

if [ ! -s "$SECTION_FILE" ]; then
  echo "ERROR: генерация секции не удалась" >&2
  exit 1
fi

# Если маркеров в README нет — добавляем секцию в конец.
if ! grep -q '<!-- PACKAGES_TABLE:START -->' "$README"; then
  echo "WARN: маркеры не найдены в $README, добавляем секцию в конец." >&2
  {
    echo ""
    cat "$SECTION_FILE"
  } >> "$README"
  echo "Секция добавлена в конец $README"
  exit 0
fi

# Заменяем содержимое между маркерами.
TMP=$(mktemp)
awk -v section_file="$SECTION_FILE" '
  /<!-- PACKAGES_TABLE:START -->/ {
    while ((getline line < section_file) > 0) print line
    close(section_file)
    skip = 1
    next
  }
  /<!-- PACKAGES_TABLE:END -->/ { skip = 0; next }
  !skip { print }
' "$README" > "$TMP"

mv "$TMP" "$README"

echo "README обновлён: $README"
echo ""
echo "Сгенерированная секция:"
echo "---"
cat "$SECTION_FILE"
echo "---"