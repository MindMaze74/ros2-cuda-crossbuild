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
# Зависимости: mikefarah/yq v4, awk, mktemp.

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

# Формируем таблицу. Поля — из config/packages.yaml.
TABLE=$(yq -r '
  "| Пакет | Репозиторий | Ветка | ROS2 | x86 | agx | nano |",
  "|---|---|---|---|---|---|---|",
  (.packages[] |
    "| `\(.name)` | [\(.repo | sub("https://github.com/"; "") | sub("\\.git$"; ""))](\(.repo)) | `\(.branch)` | `\(.ros_distro)` | `\(.cuda_arch.x86)` | `\(.cuda_arch.agx)` | `\(.cuda_arch.nano)` |"
  )
' "$PACKAGES_YAML")

PKG_COUNT=$(yq '.packages | length' "$PACKAGES_YAML")

SECTION_FILE=$(mktemp)
{
  echo '<!-- PACKAGES_TABLE:START -->'
  echo '<!-- Секция сгенерирована автоматически из config/packages.yaml. -->'
  echo '<!-- Не редактируйте вручную — правьте packages.yaml. -->'
  echo ''
  echo '## Поддерживаемые пакеты'
  echo ''
  echo "Всего пакетов: **${PKG_COUNT}**. Матрица: пакет × 3 платформы (x86 / agx / nano)."
  echo ''
  echo "$TABLE"
  echo ''
  echo 'Добавление нового пакета — одна запись в [`config/packages.yaml`](config/packages.yaml).'
  echo 'После пуша workflow `README Sync` автоматически обновит эту таблицу.'
  echo ''
  echo '<!-- PACKAGES_TABLE:END -->'
} > "$SECTION_FILE"

# Если маркеров в README нет — добавляем секцию в конец.
if ! grep -q '<!-- PACKAGES_TABLE:START -->' "$README"; then
  echo "WARN: маркеры не найдены в $README, добавляем секцию в конец." >&2
  {
    echo ""
    cat "$SECTION_FILE"
  } >> "$README"
  rm -f "$SECTION_FILE"
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
rm -f "$SECTION_FILE"

echo "README обновлён: $README"
echo ""
echo "Сгенерированная таблица:"
echo "$TABLE"