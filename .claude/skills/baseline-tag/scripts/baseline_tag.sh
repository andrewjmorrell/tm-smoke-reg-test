#!/usr/bin/env bash
# Baseline-tag an existing repository at integration: add a neutral BASELINE provenance header to every
# UNTAGGED source file, marking pre-existing code as "provenance not established" (exempt from DDR/gate).
# BASELINE is NOT a claim of human or AI authorship — the provenance of pre-existing code is unknown.
# Idempotent: files already carrying any PROVENANCE tag are left untouched. Run ONCE, then commit the
# result as a single "baseline tagging" commit — that commit is the cut-line.
#
# Usage:  bash baseline_tag.sh [dir]            # DRY RUN (default): list files that would be tagged
#         bash baseline_tag.sh [dir] --apply    # write the headers
set -euo pipefail
DIR="."; APPLY=0
for a in "$@"; do case "$a" in --apply) APPLY=1 ;; *) DIR="$a" ;; esac; done
cd "$DIR"

DATE="$(date -u +%F)"
COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo '<no-git>')"
PRUNE_RE='/(\.git|node_modules|vendor|third_party|thirdparty|3rdparty|build|dist|out|target|\.gradle|\.idea|generated|__pycache__|\.venv|venv|\.claude/throughmark|\.claude|\.gemini|reference-corpus)/'

style(){ case "$1" in
  kt|kts|java|js|jsx|ts|tsx|go|c|h|cc|cpp|cxx|hpp|hh|hxx|cs|rs|swift|m|mm|scala|php) echo "//" ;;
  py|rb|sh|bash) echo "#" ;;
  sql) echo "--" ;;
  *) echo "" ;;
esac; }

count=0; skipped=0
while IFS= read -r f; do
  printf '%s' "$f" | grep -qE "$PRUNE_RE" && continue
  ext="${f##*.}"; cs="$(style "$ext")"; [ -n "$cs" ] || continue      # only known source languages
  [ -s "$f" ] || continue
  if grep -q 'PROVENANCE' "$f" 2>/dev/null; then skipped=$((skipped+1)); continue; fi   # already tagged
  count=$((count+1))
  if [ "$APPLY" = 0 ]; then echo "WOULD-TAG  $f"; continue; fi
  header="$cs PROVENANCE: BASELINE
$cs Established: $DATE   Cut-line: $COMMIT   Note: pre-existing code; provenance not established; exempt from DDR/gate."
  tmp="$(mktemp)"; first="$(head -1 "$f")"
  if printf '%s' "$first" | grep -q '^#!'; then                       # keep shebang on line 1
    { printf '%s\n' "$first"; printf '%s\n' "$header"; tail -n +2 "$f"; } > "$tmp"
  else
    { printf '%s\n' "$header"; cat "$f"; } > "$tmp"
  fi
  cat "$tmp" > "$f"; rm -f "$tmp"; echo "TAGGED     $f"
done < <(find . -type f 2>/dev/null)

echo
if [ "$APPLY" = 0 ]; then
  echo "DRY RUN: $count file(s) would get a BASELINE header; $skipped already tagged (skipped)."
  echo "Review the list, then re-run with --apply."
else
  echo "Applied BASELINE to $count file(s); $skipped already tagged (skipped)."
  mkdir -p .claude/throughmark
  [ -f .claude/throughmark/baseline ] || printf '# cut-line: code at/before this commit is BASELINE, exempt from the gate.\ncut_line_commit: %s\nestablished: %sT00:00:00Z\n' "$COMMIT" "$DATE" > .claude/throughmark/baseline
  echo "Next: commit these as ONE 'baseline tagging' commit — that commit is the cut-line. Verify the build still passes."
fi
