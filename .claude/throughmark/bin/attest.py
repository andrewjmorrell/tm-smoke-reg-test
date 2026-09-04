#!/usr/bin/env python3
"""attest.py — non-repudiable human attestations (item 2).

Turns two text claims into cryptographic, non-repudiable signatures bound to the exact content:
  • DDR "Conceived-by: human"  -> the DEVELOPER signs an in-toto Statement over their DDR (conception).
  • validity sign-off          -> the REVIEWER signs a Statement over the PR head (validity).

Format: an in-toto Statement (recognizable, portable) signed with SSHSIG (`ssh-keygen -Y`), so developers
reuse the SSH key they already use for git commit signing. Verified against a per-client allowed-signers
registry (identity -> SSH public key) — the identity binding. Offline / air-gap capable. A Sigstore-keyless
signer (Fulcio cert + Rekor log) can replace the SSH signer later, emitting the same Statement.

CLI:
  attest.py sign-ddr      <ddr_file> --key <sshkey> --identity <id> [--trace T] --out <att.json>
  attest.py sign-validity --repo R --pr N --head <sha> --verdict valid --source "..." \
                          --key <sshkey> --identity <id> [--role "..."] --out <att.json>
  attest.py verify        <att.json> --artifact <file> --allowed-signers <file>
"""
import argparse, datetime, hashlib, json, os, subprocess, sys, tempfile

NAMESPACE = "throughmark"


def _now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(65536), b""):
            h.update(b)
    return h.hexdigest()


def canonical(stmt) -> bytes:
    return json.dumps(stmt, sort_keys=True, separators=(",", ":")).encode("utf-8")


def statement_conception(ddr_id, ddr_sha256, developer, trace):
    return {"_type": "https://in-toto.io/Statement/v1",
            "subject": [{"name": ddr_id, "digest": {"sha256": ddr_sha256}}],
            "predicateType": "https://throughmark.dev/conception/v1",
            "predicate": {"conceived_by": "human", "developer": developer, "trace": trace,
                          "attested_at": _now()}}


def statement_validity(repo, pr, head_sha, verdict, source, role):
    return {"_type": "https://in-toto.io/Statement/v1",
            "subject": [{"name": f"{repo}#{pr}@{head_sha}", "digest": {"sha1": head_sha}}],
            "predicateType": "https://throughmark.dev/validity/v1",
            "predicate": {"reviewer": None, "verdict": verdict, "source": source, "role": role,
                          "repo": repo, "pr": pr, "head_sha": head_sha, "attested_at": _now()}}


def sshsig_sign(message: bytes, key_path: str) -> str:
    """Sign via SSHSIG. Prefer the ssh-agent so a passphrase-protected key signs NON-INTERACTIVELY
    (the way skills run): ssh-keygen -Y sign can sign with the PUBLIC key while the agent holds the
    private key — no passphrase prompt. Fall back to the private-key file (which prompts if encrypted).
    stdin is /dev/null throughout so an encrypted key with no agent fails FAST with a clear error instead
    of hanging on an un-answerable passphrase prompt."""
    key_path = os.path.expanduser(key_path)
    pub = key_path + ".pub"
    candidates = []
    if os.environ.get("SSH_AUTH_SOCK") and os.path.exists(pub):
        candidates.append(pub)        # agent path — no passphrase needed
    candidates.append(key_path)       # private-key file — prompts if encrypted (interactive only)
    last = ""
    with tempfile.TemporaryDirectory() as d:
        msg = os.path.join(d, "m")
        with open(msg, "wb") as f:
            f.write(message)
        for f in candidates:
            sig = msg + ".sig"
            try:
                os.path.exists(sig) and os.remove(sig)
            except OSError:
                pass
            r = subprocess.run(["ssh-keygen", "-Y", "sign", "-f", f, "-n", NAMESPACE, msg],
                               capture_output=True, stdin=subprocess.DEVNULL)
            if r.returncode == 0 and os.path.exists(sig):
                with open(sig, encoding="utf-8") as fh:
                    return fh.read()
            last = r.stderr.decode()[:300]
    raise RuntimeError(
        "ssh-keygen sign failed: " + last +
        " | If your signing key has a passphrase, load it into the agent once and retry: "
        "`ssh-add " + key_path + "` (macOS: `ssh-add --apple-use-keychain " + key_path + "`).")


def sshsig_verify(message: bytes, sig_armored: str, identity: str, allowed_signers: str) -> bool:
    with tempfile.TemporaryDirectory() as d:
        sig = os.path.join(d, "m.sig")
        with open(sig, "w", encoding="utf-8") as f:
            f.write(sig_armored)
        r = subprocess.run(["ssh-keygen", "-Y", "verify", "-f", os.path.expanduser(allowed_signers),
                            "-I", identity, "-n", NAMESPACE, "-s", sig],
                           input=message, capture_output=True)
        return r.returncode == 0


def sign(stmt, identity, key_path):
    stmt = json.loads(json.dumps(stmt))
    # stamp identity into the predicate actor field
    pred = stmt["predicate"]
    if "developer" in pred and pred["developer"] is None:
        pred["developer"] = identity
    if "reviewer" in pred and pred["reviewer"] is None:
        pred["reviewer"] = identity
    msg = canonical(stmt)
    return {"statement": stmt,
            "signature": {"identity": identity, "namespace": NAMESPACE, "sshsig": sshsig_sign(msg, key_path)}}


def verify(att, artifact_path, allowed_signers):
    stmt = att["statement"]; sig = att["signature"]
    problems = []
    if not sshsig_verify(canonical(stmt), sig["sshsig"], sig["identity"], allowed_signers):
        problems.append("BAD-SIGNATURE: signature does not verify for identity "
                        f"'{sig['identity']}' against the allowed-signers registry")
    if artifact_path:
        want = stmt["subject"][0]["digest"].get("sha256")
        if want:
            got = _sha256_file(artifact_path)
            if got != want:
                problems.append(f"SUBJECT-MISMATCH: artifact sha256 {got[:12]}… != attested {want[:12]}…")
    return problems


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    d = sub.add_parser("sign-ddr"); d.add_argument("ddr"); d.add_argument("--key", required=True)
    d.add_argument("--identity", required=True); d.add_argument("--trace", default="")
    d.add_argument("--out", required=True)
    v = sub.add_parser("sign-validity")
    for a in ("--repo", "--pr", "--head", "--verdict", "--source", "--key", "--identity", "--out"):
        v.add_argument(a, required=(a not in ("--source",)))
    v.add_argument("--role", default="")
    vf = sub.add_parser("verify"); vf.add_argument("att"); vf.add_argument("--artifact", default="")
    vf.add_argument("--allowed-signers", required=True)
    args = ap.parse_args()

    if args.cmd == "sign-ddr":
        ddr_id = os.path.splitext(os.path.basename(args.ddr))[0]
        stmt = statement_conception(ddr_id, _sha256_file(args.ddr), None, args.trace)
        att = sign(stmt, args.identity, args.key)
        json.dump(att, open(args.out, "w"), indent=2)
        print(f"signed conception of {ddr_id} by {args.identity} -> {args.out}")
    elif args.cmd == "sign-validity":
        stmt = statement_validity(args.repo, args.pr, args.head, args.verdict, args.source or "", args.role)
        att = sign(stmt, args.identity, args.key)
        json.dump(att, open(args.out, "w"), indent=2)
        print(f"signed validity of {args.repo}#{args.pr}@{args.head[:8]} by {args.identity} -> {args.out}")
    elif args.cmd == "verify":
        att = json.load(open(args.att))
        probs = verify(att, args.artifact or None, args.allowed_signers)
        if probs:
            print("INVALID:"); [print("  - " + p) for p in probs]; sys.exit(1)
        print(f"VALID: {att['signature']['identity']} — {att['statement']['predicateType']}")


if __name__ == "__main__":
    main()
