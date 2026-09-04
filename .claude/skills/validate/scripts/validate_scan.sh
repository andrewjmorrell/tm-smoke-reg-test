#!/usr/bin/env bash
# Read-only scanner for the `validate` skill. Emits one gap-finding per line (TAB-separated:
# KIND<TAB>LOCATION<TAB>DETAIL) that the skill then remediates interactively. Never edits anything.
# A section the developer has already resolved is SILENT: BOILERPLATE, or a HUMAN-AUTHORED fence carrying
# `DDR: none` (explicit "no DDR needed"), or a `DDR: <id>` that resolves to a real record — none re-reported.
#
# Usage:  validate_scan.sh [TARGET]
#   (no arg = files changed vs ${BASE:-origin/main}; a file/dir = just that; --all = whole working tree)
set -euo pipefail
py_is3(){ "$1" -c "import sys; sys.exit(0 if sys.version_info[0]==3 else 1)" >/dev/null 2>&1; }; PY=""; for _c in python3 python; do _p="$(command -v "$_c" 2>/dev/null || true)"; [ -n "$_p" ] && py_is3 "$_p" && { PY="$_p"; break; }; done
[ -n "$PY" ] || { echo "validate_scan: no runnable python3 found (need Python 3)" >&2; exit 3; }
CFG=".claude/throughmark/config"; DDR_DIR="docs/ddr"; DDR_LOG="docs/DDR.md"
[ -f "$CFG" ] && . "$CFG"
GUARD="$(ls .claude/throughmark/throughmark.md .gemini/throughmark/throughmark.md 2>/dev/null | head -1 || true)"
REGULATED=0
{ [ -n "$GUARD" ] && grep -qiE 'prove TRACEABILITY|cite an external source|cite a source for every' "$GUARD"; } && REGULATED=1
[ "$REGULATED" = 0 ] && grep -qiE 'cite an external source|prove TRACEABILITY' AGENTS.md 2>/dev/null && REGULATED=1

TARGET="${1:-}"
file_list(){
  if [ "$TARGET" = "--all" ]; then git ls-files 2>/dev/null; git ls-files --others --exclude-standard 2>/dev/null
  elif [ -n "$TARGET" ] && [ -e "$TARGET" ]; then
    if [ -d "$TARGET" ]; then find "$TARGET" -type f 2>/dev/null; else printf '%s\n' "$TARGET"; fi
  else git diff --name-only "${BASE:-origin/main}"...HEAD 2>/dev/null || git ls-files 2>/dev/null; fi
}

# UNTAGGED files (reuse the tag skill's scanner if present)
UT=".claude/skills/tag/scripts/scan_untagged.sh"
if [ -x "$UT" ] || [ -f "$UT" ]; then
  file_list | sort -u | while IFS= read -r f; do
    [ -f "$f" ] || continue
    if bash "$UT" "$f" 2>/dev/null | grep -q .; then printf 'UNTAGGED\t%s\t has unfenced code — run /tag to label it\n' "$f"; fi
  done
fi

# fence-level findings (DDR / Sources / FLAGGED / well-formedness) via embedded python.
# NOTE: the file list is passed as argv (a temp file), not stdin — a heredoc script (python3 - <<PY)
# already owns stdin, so a piped file list would be silently discarded.
_TMPF="$(mktemp)"; file_list | sort -u > "$_TMPF"
DDR_DIR="$DDR_DIR" DDR_LOG="$DDR_LOG" REGULATED="$REGULATED" "$PY" - "$_TMPF" <<'PY'
import os, re, sys
DDR_DIR=os.environ.get("DDR_DIR","docs/ddr"); DDR_LOG=os.environ.get("DDR_LOG","docs/DDR.md")
REG=os.environ.get("REGULATED","0")=="1"
CODE={"py","js","jsx","ts","tsx","kt","kts","java","go","c","cc","cpp","h","hpp","cs","rs","rb","sh","sql","hs","swift","m","mm","scala","php"}
MARK=re.compile(r"PROVENANCE(-BEGIN|-END)?:\s*([A-Z][A-Z-]*)")
DDRRE=re.compile(r"DDR:\s*([^\s)]+)")
SRCRE=re.compile(r"Sources?:\s*\S")
ALLOWED={"BOILERPLATE","AI-DRAFTED","FLAGGED","HUMAN-AUTHORED","BASELINE","THIRD-PARTY-OSS","VENDOR-DOC"}

def ddr_exists(idv):
    if os.path.isfile(os.path.join(DDR_DIR, idv+".md")): return True
    if os.path.isfile(DDR_LOG):
        try:
            with open(DDR_LOG,encoding="utf-8",errors="ignore") as f:
                return re.search(r"^##\s+"+re.escape(idv)+r"(\s|—|-|$)", f.read(), re.M) is not None
        except Exception: pass
    return False

def header(lines, i):
    """begin line + following comment continuation lines (before code / next marker)."""
    out=[lines[i]]; ln=lines[i]; p=ln.find("PROVENANCE"); mk=(ln[:p].strip() or "#") if p>=0 else "#"
    for j in range(i+1, min(i+9, len(lines))):
        nx=lines[j]
        if "PROVENANCE" in nx or not nx.strip().startswith(mk): break
        out.append(nx)
    return "\n".join(out)

for path in (l.strip() for l in open(sys.argv[1]) if l.strip()):
    if path.split(".")[-1] not in CODE or not os.path.isfile(path): continue
    try: lines=open(path,encoding="utf-8",errors="ignore").read().splitlines()
    except Exception: continue
    stack=[]
    for i,line in enumerate(lines):
        m=MARK.search(line)
        if not m: continue
        kind,tag=m.group(1),m.group(2); ln=i+1
        if tag not in ALLOWED: print(f"BAD-TAG\t{path}:{ln}\tunknown provenance tag {tag}")
        if kind=="-BEGIN":
            stack.append((tag,ln)); hdr=header(lines,i)
            if tag=="HUMAN-AUTHORED":
                dm=DDRRE.search(hdr); dv=(dm.group(1) if dm else "")
                if not dv or dv.upper()=="TBD":
                    print(f"DDR-NEEDED\t{path}:{ln}\tHUMAN-AUTHORED needs a decision: write a DDR, or mark 'DDR: none', or downgrade to BOILERPLATE")
                elif dv.lower()!="none" and not ddr_exists(dv):
                    print(f"DDR-MISSING-FILE\t{path}:{ln}\tDDR: {dv} does not resolve to {DDR_DIR}/{dv}.md — fix the link or create the record")
            if REG and tag in ("AI-DRAFTED","FLAGGED") and not SRCRE.search(hdr):
                print(f"SOURCE-NEEDED\t{path}:{ln}\t{tag} block has no Sources: (regulated) — cite an approved source or mark for review")
            if tag=="FLAGGED":
                print(f"FLAGGED-OPEN\t{path}:{ln}\tFLAGGED (resembles a known source) — resolve via flag triage before merge")
        elif kind=="-END":
            if not stack or stack[-1][0]!=tag: print(f"MALFORMED-FENCE\t{path}:{ln}\tEND {tag} without a matching BEGIN")
            else: stack.pop()
    for tag,ln in stack: print(f"MALFORMED-FENCE\t{path}:{ln}\tBEGIN {tag} is never closed")
PY
rm -f "$_TMPF"
