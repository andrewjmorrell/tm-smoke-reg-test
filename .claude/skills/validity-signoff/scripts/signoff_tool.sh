#!/usr/bin/env bash
# Helper for the validity-signoff skill. The SKILL guides the human reviewer through an actual validity
# review; this helper does only the mechanical, auditable steps: resolve the PR, ENFORCE reviewer != author
# (separation of duties), write the immutable sign-off record to the WORM sink (create-only), and post the
# `throughmark-validity` commit status. The human reviewer — running this in their own authenticated gh
# session and stating their own verdict — is the attributable actor. Config: .claude/throughmark/config.
#
# Usage:
#   signoff_tool.sh context <pr> [--repo <owner/name>]
#   signoff_tool.sh record  <pr> --verdict valid|invalid|conditions --source "<what you checked against>" \
#                                [--source-version "<edition/rev>"] [--role "<your qualification>"] \
#                                [--notes "..."] [--repo <owner/name>]
set -euo pipefail
py_is3(){ "$1" -c "import sys; sys.exit(0 if sys.version_info[0]==3 else 1)" >/dev/null 2>&1; }; PY=""; for _c in python3 python; do _p="$(command -v "$_c" 2>/dev/null || true)"; [ -n "$_p" ] && py_is3 "$_p" && { PY="$_p"; break; }; done
[ -n "$PY" ] || { echo "no runnable python3 found (need Python 3)"; exit 1; }

CFG=".claude/throughmark/config"
SINK_BUCKET="${SINK_BUCKET:-}"; PROJECT="${PROJECT:-}"
[ -f "$CFG" ] && . "$CFG"                    # may set SINK_BUCKET / PROJECT
BUCKET="${SINK_BUCKET:-}"; [ -z "$BUCKET" ] && [ -n "${PROJECT:-}" ] && BUCKET="${PROJECT}-ai-logs"

command -v gh >/dev/null || { echo "gh not installed — the reviewer runs this in their own gh session"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "not logged in — run 'gh auth login' as the REVIEWER (not the author)"; exit 1; }

CMD="${1:?usage: signoff_tool.sh context|record <pr> ...}"; shift
PR="${1:?pr number required}"; shift || true
VERDICT=""; SOURCE=""; SVER=""; ROLE=""; NOTES=""; REPO_ARG=""
while [ $# -gt 0 ]; do case "$1" in
  --verdict) VERDICT="$2"; shift 2;;
  --source) SOURCE="$2"; shift 2;;
  --source-version) SVER="$2"; shift 2;;
  --role) ROLE="$2"; shift 2;;
  --notes) NOTES="$2"; shift 2;;
  --repo) REPO_ARG="$2"; shift 2;;
  *) echo "unknown arg: $1"; exit 2;;
esac; done

SLUG="${REPO_ARG:-$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)}"
[ -n "$SLUG" ] || { echo "could not resolve repo — pass --repo <owner/name> (or run inside the repo)"; exit 1; }
REVIEWER="$(gh api user --jq .login 2>/dev/null || echo '')"
AUTHOR="$(gh api "repos/$SLUG/pulls/$PR" --jq .user.login 2>/dev/null || echo '')"
HEAD_SHA="$(gh api "repos/$SLUG/pulls/$PR" --jq .head.sha 2>/dev/null || echo '')"
[ -n "$REVIEWER" ] && [ -n "$HEAD_SHA" ] && [ -n "$AUTHOR" ] || { echo "could not resolve reviewer / PR $PR head/author on $SLUG"; exit 1; }
SOD_OK=yes; [ "$REVIEWER" = "$AUTHOR" ] && SOD_OK=no

if [ "$CMD" = "context" ]; then
  echo "repo=$SLUG"; echo "pr=$PR"; echo "author=$AUTHOR"; echo "reviewer=$REVIEWER"
  echo "head_sha=$HEAD_SHA"; echo "separation_of_duties_ok=$SOD_OK"
  echo "sink_bucket=${BUCKET:-<none — record write will be skipped>}"
  exit 0
fi

[ "$CMD" = "record" ] || { echo "unknown command: $CMD (use context|record)"; exit 2; }
: "${VERDICT:?--verdict valid|invalid|conditions required}"
: "${SOURCE:?--source \"<what you checked it against>\" required}"
case "$VERDICT" in valid|invalid|conditions) ;; *) echo "verdict must be valid|invalid|conditions"; exit 2;; esac
if [ "$SOD_OK" = no ]; then
  echo "separation of duties: reviewer ($REVIEWER) must not be the PR author ($AUTHOR). Sign off as a different, qualified reviewer."; exit 3
fi

TS="$(date -u +%FT%TZ)"
REC="$(mktemp).json"
"$PY" - "$REC" "$SLUG" "$PR" "$HEAD_SHA" "$REVIEWER" "$AUTHOR" "$ROLE" "$VERDICT" "$SOURCE" "$SVER" "$NOTES" "$TS" <<'PY'
import sys, json
out,slug,pr,sha,rev,author,role,verdict,src,sver,notes,ts = sys.argv[1:13]
json.dump({"kind":"validity-signoff","repo":slug,"pr_number":int(pr),"head_sha":sha,
           "reviewer":rev,"author":author,"role":role or None,"verdict":verdict,
           "source":src,"source_version":sver or None,"notes":notes or None,
           "signed_at":ts,"channel":"cli-skill","signed_by":"reviewer"}, open(out,"w"), indent=2)
PY

# Optional non-repudiable SSHSIG attestation, if the reviewer has an SSH signing key.
SIGNKEY="${TM_SIGN_KEY:-$(git config user.signingkey 2>/dev/null || echo '')}"; SIGNKEY="${SIGNKEY%.pub}"
ATTEST_BIN=".claude/throughmark/bin/attest.py"
if [ -n "$SIGNKEY" ] && [ -f "$SIGNKEY" ] && [ -f "$ATTEST_BIN" ]; then
  ATT="$(mktemp).json"
  if "$PY" "$ATTEST_BIN" sign-validity --repo "$SLUG" --pr "$PR" --head "$HEAD_SHA" \
       --verdict "$VERDICT" --source "$SOURCE" --role "$ROLE" \
       --key "$SIGNKEY" --identity "$REVIEWER" --out "$ATT" >/dev/null 2>&1; then
    "$PY" - "$REC" "$ATT" <<'PY2'
import sys, json
rec = json.load(open(sys.argv[1])); rec["attestation"] = json.load(open(sys.argv[2]))
json.dump(rec, open(sys.argv[1], "w"), indent=2)
PY2
    echo "==> attached signed reviewer attestation (SSHSIG) for $REVIEWER"
  else echo "    (attestation signing skipped — check the signing key / ssh-keygen -Y)"; fi
  rm -f "$ATT"
fi

if [ -n "$BUCKET" ]; then
  DEST="signoffs/$SLUG/$PR/$HEAD_SHA.cli-$REVIEWER.json"
  echo "==> immutable sign-off -> gs://$BUCKET/$DEST"
  gcloud storage cp --if-generation-match=0 "$REC" "gs://$BUCKET/$DEST" >/dev/null 2>&1 \
    || echo "    (sink write skipped — object already exists, or you lack write on gs://$BUCKET/signoffs)"
else
  echo "!! no SINK_BUCKET/PROJECT in $CFG and none in env — the commit status will still post, but the"
  echo "   immutable sink record was NOT written. Set SINK_BUCKET (or PROJECT) to capture the record."
fi
rm -f "$REC"

STATE="$([ "$VERDICT" = valid ] && echo success || echo failure)"
echo "==> posting commit status throughmark-validity=$STATE on $HEAD_SHA"
gh api -X POST "repos/$SLUG/statuses/$HEAD_SHA" \
  -f state="$STATE" -f context="throughmark-validity" \
  -f description="validity sign-off by $REVIEWER ($VERDICT) vs $SOURCE" >/dev/null

echo "==> done. PR #$PR head ${HEAD_SHA:0:7} signed off ($VERDICT) by $REVIEWER."
[ "$VERDICT" = valid ] || echo "NOTE: verdict=$VERDICT posts a FAILING status — the PR stays blocked (as it should)."
