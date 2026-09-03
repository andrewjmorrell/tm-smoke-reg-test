#!/usr/bin/env bash
# List CODE files to consider for tagging, and whether each already carries a provenance tag.
# TARGET selects the scope:
#   scan_untagged.sh                 -> CHANGED files vs origin/main (committed diff + working tree + untracked)
#   scan_untagged.sh <git-ref>       -> CHANGED files vs <git-ref>
#   scan_untagged.sh <file>          -> just that file (even if unchanged since last commit)
#   scan_untagged.sh <dir>           -> every code file under that directory/module (even if unchanged)
# Output lines: "HAS-TAGS  <file>" (already has fences/header) or "UNTAGGED  <file>".
# A HAS-TAGS file may still contain NEW unfenced regions — the tag skill inspects each file regardless.
set -euo pipefail

is_code(){ case "$1" in
  *.py|*.js|*.ts|*.tsx|*.jsx|*.java|*.kt|*.kts|*.go|*.c|*.h|*.cc|*.cpp|*.cxx|*.hpp|*.cs|*.rs|*.rb|*.sh|*.bash|*.sql|*.hs|*.swift|*.scala|*.php) return 0;; *) return 1;; esac; }
excluded(){ case "$1" in
  */.git/*|*/vendor/*|*/node_modules/*|*/.cache/*|*/_reports/*|*/build/*|*/dist/*|*/out/*|*/target/*|*/.gradle/*|*/.idea/*|*/generated/*|*/__pycache__/*|*/.venv/*|*/venv/*|*/reference-corpus/*) return 0;; *) return 1;; esac; }

TARGET="${1:-}"
MODE="changed"
if [ -n "$TARGET" ] && [ -f "$TARGET" ]; then
  MODE="file";  files="$TARGET"
elif [ -n "$TARGET" ] && [ -d "$TARGET" ]; then
  MODE="dir";   files="$(find "$TARGET" -type f 2>/dev/null | sort)"
else
  BASE="${TARGET:-origin/main}"
  files="$( { git diff --name-only "$BASE"...HEAD 2>/dev/null || true
              git diff --name-only 2>/dev/null || true
              git ls-files --others --exclude-standard 2>/dev/null || true; } | sort -u )"
fi

any=0; listed=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  [ -f "$f" ] || continue
  is_code "$f" || continue
  excluded "$f" && continue
  listed=1
  if grep -qE 'PROVENANCE(-BEGIN)?:' "$f" 2>/dev/null; then
    echo "HAS-TAGS  $f"
  else
    echo "UNTAGGED  $f"; any=1
  fi
done <<EOF
$files
EOF

if [ "$listed" = 0 ]; then
  echo "(no code files in scope [$MODE]${TARGET:+: $TARGET})"
elif [ "$any" = 0 ]; then
  echo "(all in-scope files already carry tags — inspect HAS-TAGS files for any new unfenced regions)"
fi
exit 0
