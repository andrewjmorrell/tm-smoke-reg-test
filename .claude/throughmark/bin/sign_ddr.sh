#!/usr/bin/env bash
# sign_ddr.sh (developer kit) — create a DDR's non-repudiable conception attestation (item 2) using a
# usable SSH signing key, and auto-register that key in .claude/throughmark/allowed_signers so the gate
# can verify it. Idempotent: re-run after ANY edit to a DDR (an edit invalidates the old signature).
#
# Designed for the way developers actually run this: inside a Claude plugin in an IDE (Antigravity, VS
# Code, Android Studio, …). That process has NO TTY and usually NO ssh-agent, so signing must work with
# neither. Resolution order picks the first key that can sign with no prompt and no agent dependency; if
# none exists it auto-provisions a dedicated, passphrase-less, SIGNING-ONLY key (opt out: TM_SIGN_NO_AUTOKEY=1).
# Signing is advisory until the client enables ATTEST_ENFORCE. Commit <ddr>.md.att.json ALONGSIDE the DDR.
#
# Usage:  bash .claude/throughmark/bin/sign_ddr.sh docs/ddr/DDR-<id>.md [--trace T]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DDR="${1:?usage: sign_ddr.sh <ddr-file> [--trace T]}"; shift || true
TRACE=""; [ "${1:-}" = "--trace" ] && TRACE="${2:-}"
[ -f "$DDR" ] || { echo "no such DDR: $DDR"; exit 1; }
command -v ssh-keygen >/dev/null || { echo "note: ssh-keygen not found — DDR left unsigned (advisory)."; exit 0; }
py_is3(){ "$1" -c "import sys; sys.exit(0 if sys.version_info[0]==3 else 1)" >/dev/null 2>&1; }; PY=""; for _c in python3 python; do _p="$(command -v "$_c" 2>/dev/null || true)"; [ -n "$_p" ] && py_is3 "$_p" && { PY="$_p"; break; }; done
[ -n "$PY" ] || { echo "note: no runnable python3 — DDR left unsigned (advisory)."; exit 0; }

ID="$(git config user.email 2>/dev/null || echo "${USER:-dev}")"
DEDICATED="$HOME/.ssh/throughmark_ed25519"

pub_of(){ # print the "<type> <value>" public key for key $1 WITHOUT needing a passphrase where possible
  local k="$1"
  [ -f "$k.pub" ] && { awk '{print $1" "$2}' "$k.pub"; return 0; }
  ssh-keygen -y -f "$k" </dev/null 2>/dev/null | awk '{print $1" "$2}' && return 0   # unencrypted key
  return 1; }
in_agent(){ # is key $1's public half currently loaded in the ssh-agent?
  [ -n "${SSH_AUTH_SOCK:-}" ] || return 1
  local v; v="$(pub_of "$1" 2>/dev/null | awk '{print $2}')"; [ -n "$v" ] || return 1
  ssh-add -L 2>/dev/null | grep -qF "$v"; }
signable(){ # key exists AND can sign with no prompt: unencrypted OR loaded in the agent
  local k="$1"; [ -f "$k" ] || return 1
  ssh-keygen -y -f "$k" </dev/null >/dev/null 2>&1 && return 0
  in_agent "$k"; }

# pick the first USABLE key. TM_SIGN_KEY is honored when the environment carries it (shells), but the
# dedicated fixed path is what makes this work inside an IDE plugin that inherits no such env var.
KEY=""
for c in "${TM_SIGN_KEY:-}" "$DEDICATED" "$(git config user.signingkey 2>/dev/null || true)" "$HOME/.ssh/id_ed25519"; do
  c="${c%.pub}"; [ -n "$c" ] || continue
  signable "$c" && { KEY="$c"; break; }
done

if [ -z "$KEY" ]; then
  if [ "${TM_SIGN_NO_AUTOKEY:-0}" = 1 ]; then
    echo "note: no usable signing key (none unencrypted or loaded in the ssh-agent), and auto-provisioning"
    echo "      is disabled (TM_SIGN_NO_AUTOKEY=1). Options:"
    echo "        • load your key in the agent:  ssh-add ~/.ssh/id_ed25519   (needs its passphrase)"
    echo "        • or create a dedicated key:   ssh-keygen -t ed25519 -f $DEDICATED -N \"\" -C throughmark-$ID"
    echo "      DDR left UNSIGNED (advisory until ATTEST_ENFORCE); its content is unchanged."
    exit 3
  fi
  echo "note: no usable signing key found (none unencrypted or agent-loaded — expected inside an IDE plugin"
  echo "      with no TTY/agent). Auto-provisioning a dedicated ThroughMark signing key (passphrase-less;"
  echo "      only signs DDR attestations, never used for auth): $DEDICATED"
  mkdir -p "$HOME/.ssh"
  if ssh-keygen -t ed25519 -f "$DEDICATED" -N "" -C "throughmark-$ID" >/dev/null 2>&1; then
    chmod 600 "$DEDICATED" 2>/dev/null || true; KEY="$DEDICATED"
    echo "      created $DEDICATED  (set TM_SIGN_NO_AUTOKEY=1 to require an agent/hardware key instead)."
  else
    echo "      could not create it — create one yourself: ssh-keygen -t ed25519 -f $DEDICATED -N \"\""
    exit 3
  fi
fi

# register THIS key's pubkey for the identity — keyed on the PUBKEY (not just the identity), so a rotated
# or additional key is added rather than silently skipped (a reviewer sees the new signer in the PR diff).
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REG="$ROOT/.claude/throughmark/allowed_signers"; mkdir -p "$(dirname "$REG")"; touch "$REG"
PUB="$(pub_of "$KEY" 2>/dev/null || true)"
if [ -n "$PUB" ] && ! grep -qF "$PUB" "$REG" 2>/dev/null; then
  printf '%s %s\n' "$ID" "$PUB" >> "$REG"
  echo "→ registered $ID's signing key in .claude/throughmark/allowed_signers (commit it — reviewers see new signers)"
fi

if ! "$PY" "$HERE/attest.py" sign-ddr "$DDR" --key "$KEY" --identity "$ID" ${TRACE:+--trace "$TRACE"} --out "$DDR.att.json"; then
  echo "note: signing failed with key '$KEY'. DDR content is unchanged; it is just UNSIGNED (advisory)."
  exit 3
fi
echo "→ signed $DDR with $KEY → $DDR.att.json  (commit BOTH, together)"
