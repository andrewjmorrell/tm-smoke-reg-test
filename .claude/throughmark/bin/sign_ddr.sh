#!/usr/bin/env bash
# sign_ddr.sh (developer kit) — create a DDR's non-repudiable conception attestation (item 2) using the
# developer's own SSH signing key, and auto-register that key in .claude/throughmark/allowed_signers so
# the gate can verify it. Idempotent: re-run after ANY edit to a DDR (an edit invalidates the old
# signature). Best-effort: with no SSH key it prints how to set one and leaves the DDR unsigned (signing
# is advisory until the client enables ATTEST_ENFORCE). Commit <ddr>.md.att.json ALONGSIDE the DDR.
#
# Usage:  bash .claude/throughmark/bin/sign_ddr.sh docs/ddr/DDR-<id>.md [--trace T]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
DDR="${1:?usage: sign_ddr.sh <ddr-file> [--trace T]}"; shift || true
TRACE=""; [ "${1:-}" = "--trace" ] && TRACE="${2:-}"
[ -f "$DDR" ] || { echo "no such DDR: $DDR"; exit 1; }
command -v ssh-keygen >/dev/null || { echo "note: ssh-keygen not found — DDR left unsigned (advisory)."; exit 0; }

ID="$(git config user.email 2>/dev/null || echo "${USER:-dev}")"
KEY="${TM_SIGN_KEY:-$(git config user.signingkey 2>/dev/null || echo "$HOME/.ssh/id_ed25519")}"; KEY="${KEY%.pub}"
if [ ! -f "$KEY" ]; then
  echo "note: no SSH signing key at '$KEY'."
  echo "      set one with:  git config user.signingkey ~/.ssh/id_ed25519   (or export TM_SIGN_KEY=<key>)"
  echo "      DDR left unsigned — signing is advisory until the client enables ATTEST_ENFORCE."
  exit 0
fi

# auto-register this identity's public key in the client-maintained allowed-signers registry (committed
# and reviewed — a reviewer sees any new signer in the PR diff). Only adds if the identity is absent.
ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
REG="$ROOT/.claude/throughmark/allowed_signers"; mkdir -p "$(dirname "$REG")"; touch "$REG"
PUB="$(cat "$KEY.pub" 2>/dev/null || ssh-keygen -y -f "$KEY" 2>/dev/null || true)"
if [ -n "$PUB" ] && ! grep -q "^$ID " "$REG" 2>/dev/null; then
  printf '%s %s\n' "$ID" "$PUB" >> "$REG"
  echo "→ registered $ID in .claude/throughmark/allowed_signers (commit it — reviewers see new signers)"
fi

python3 "$HERE/attest.py" sign-ddr "$DDR" --key "$KEY" --identity "$ID" ${TRACE:+--trace "$TRACE"} --out "$DDR.att.json"
echo "→ signed $DDR → $DDR.att.json  (commit BOTH, together)"
