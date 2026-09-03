#!/usr/bin/env bash
# Helper for the update-ddr skill. Read-only: locates DDRs; the skill does the editing.
# DDRs are one file per decision under DDR_DIR (default docs/ddr), with a legacy single DDR_LOG still
# read if present. Config comes from .claude/throughmark/config.
#
# Usage:
#   ddr_tool.sh ids-in <file>   # DDR-<id>s referenced by that file's fences, in file order
#   ddr_tool.sh show <id>       # print the record for one DDR id (and its file path)
#   ddr_tool.sh file <id>       # print the path of the file that declares <id> (for editing)
#   ddr_tool.sh list            # list all DDR ids + titles across the store
set -euo pipefail

CFG=".claude/throughmark/config"
DDR_DIR="docs/ddr"; DDRLOG="docs/DDR.md"
[ -f "$CFG" ] && . "$CFG"
DDR_DIR="${DDR_DIR}"; DDRLOG="${DDR_LOG:-$DDRLOG}"

ddr_sources(){ { [ -d "$DDR_DIR" ] && find "$DDR_DIR" -type f -name '*.md' 2>/dev/null
                 [ -f "$DDRLOG" ] && printf '%s\n' "$DDRLOG"; } ; }
decl_file(){ local id="$1" f
  while IFS= read -r f; do [ -n "$f" ] || continue
    grep -qE "^##[[:space:]]+$id( |—|-|\$)" "$f" && { printf '%s' "$f"; return 0; }
  done < <(ddr_sources); return 1; }

cmd="${1:-}"; shift || true
case "$cmd" in
  ids-in)
    f="${1:?usage: ddr_tool.sh ids-in <file>}"
    [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
    grep -oE 'DDR:[[:space:]]*DDR-[0-9A-Za-z_-]+' "$f" 2>/dev/null \
      | grep -oE 'DDR-[0-9A-Za-z_-]+' | awk '!seen[$0]++'
    ;;
  show)
    id="${1:?usage: ddr_tool.sh show <id>}"
    file="$(decl_file "$id" || true)"; [ -n "$file" ] || { echo "$id not found under $DDR_DIR/ or $DDRLOG" >&2; exit 1; }
    echo "# file: $file"
    awk -v id="## $id" '$0 ~ "^"id{f=1} f&&/^## /&&$0!~"^"id{exit} f{print}' "$file"
    ;;
  file)
    id="${1:?usage: ddr_tool.sh file <id>}"
    file="$(decl_file "$id" || true)"; [ -n "$file" ] || { echo "$id not found" >&2; exit 1; }
    printf '%s\n' "$file"
    ;;
  list)
    n=0
    while IFS= read -r f; do [ -n "$f" ] || continue
      grep -HnE '^##[[:space:]]+DDR-' "$f" 2>/dev/null && n=1
    done < <(ddr_sources)
    [ "$n" = 0 ] && echo "(no DDR records under $DDR_DIR/ or $DDRLOG)"
    ;;
  *)
    echo "usage: ddr_tool.sh {ids-in <file> | show <id> | file <id> | list}" >&2; exit 2 ;;
esac
