#!/usr/bin/env python3
"""ThroughMark 'throughmark-sources' MCP server.

Regulated posture. Serves the client's CURRENT approved-source list AND searches the approved sources,
logging every consultation to the immutable sink so what a piece of code was sourced from is auditable.

Tools:
  list_approved_sources()                 -> the current approved/preferred sources + priority order.
  search_approved_sources(query, trace?)  -> code matches from approved repos + the other approved refs,
                                             and writes a create-only consultation record to the sink.

The list lives centrally ($TM_SOURCES_URI: gs:// | https:// | file), read fresh each call.
Env (set in .mcp.json): TM_SOURCES_URI, TM_SINK_BUCKET (WORM sink for consults), TM_GH_TOKEN (optional;
else falls back to the `gh` CLI). Stdlib-only.
"""
import datetime, json, os, subprocess, sys, uuid
from shutil import which

NAME = "throughmark-sources"
VERSION = "0.2.0"
DEFAULT_PROTOCOL = "2024-11-05"


def _now():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_sources() -> dict:
    uri = os.environ.get("TM_SOURCES_URI", "").strip()
    data = None
    src = uri or "(fallback)"
    if uri:
        try:
            if uri.startswith("gs://"):
                r = subprocess.run(["gcloud", "storage", "cat", uri], capture_output=True, text=True, timeout=20)
                if r.returncode == 0:
                    data = r.stdout
            elif uri.startswith(("http://", "https://")):
                import urllib.request
                with urllib.request.urlopen(uri, timeout=20) as resp:
                    data = resp.read().decode("utf-8", "replace")
            else:
                with open(os.path.expanduser(uri), encoding="utf-8") as f:
                    data = f.read()
        except Exception:
            data = None
    fell_back = False
    if data is None:
        fb = os.path.join(os.path.dirname(os.path.abspath(__file__)), "approved-sources.json")
        try:
            with open(fb, encoding="utf-8") as f:
                data = f.read()
            src = fb
        except Exception:
            data = '{"sources": []}'
            src = "(none)"
        fell_back = True
    try:
        parsed = json.loads(data)
        if not isinstance(parsed, dict):
            parsed = {"sources": parsed}
    except Exception as e:
        parsed = {"sources": [], "error": f"approved-sources is not valid JSON: {e}"}
    parsed["_source_uri"] = src
    parsed["_fallback"] = fell_back
    return parsed


def _gh_token():
    return os.environ.get("TM_GH_TOKEN") or os.environ.get("GH_TOKEN") or ""


def gh_code_search(query, repo, limit):
    """Search approved code via GitHub code search. `repo` is EITHER 'owner/name' (one repo) OR a bare
    'owner' (every repo that owner owns -> user:/org: scope). Uses a token if present, else the gh CLI.
    Degrades to [] (never raises) if neither is available or the call fails."""
    scope = f"repo:{repo}" if "/" in repo else f"user:{repo}"   # bare owner => search all their repos
    q = f"{query} {scope}"
    out = []
    tok = _gh_token()
    try:
        if tok:
            import urllib.request, urllib.parse
            url = ("https://api.github.com/search/code?q=" + urllib.parse.quote(q) + f"&per_page={limit}")
            req = urllib.request.Request(url, headers={
                "Authorization": "Bearer " + tok, "Accept": "application/vnd.github+json",
                "User-Agent": "throughmark-sources", "X-GitHub-Api-Version": "2022-11-28"})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = json.loads(r.read())
            for it in data.get("items", [])[:limit]:
                out.append({"repo": it["repository"]["full_name"], "path": it.get("path"),
                            "url": it.get("html_url"), "sha": (it.get("sha") or "")[:12]})
        elif which("gh"):
            r = subprocess.run(["gh", "api", "-X", "GET", "/search/code", "-f", "q=" + q,
                                "-F", "per_page=" + str(limit), "--jq",
                                '.items[] | {repo: .repository.full_name, path: .path, url: .html_url, sha: .sha}'],
                               capture_output=True, text=True, timeout=25)
            if r.returncode == 0:
                for ln in r.stdout.splitlines():
                    try:
                        m = json.loads(ln); m["sha"] = (m.get("sha") or "")[:12]; out.append(m)
                    except Exception:
                        pass
    except Exception:
        pass
    return out


def log_consultation(rec) -> str:
    """Write a create-only consultation record to the WORM sink; fall back to a local file. Never raises."""
    payload = json.dumps(rec, indent=2).encode("utf-8")
    bucket = os.environ.get("TM_SINK_BUCKET", "").strip()
    key = f"consults/{rec.get('trace') or '_untraced'}/{rec['id']}.json"
    if bucket and which("gcloud"):
        try:
            # TM_SINK_SA (a write-only capture SA, set by dev_setup) routes the consult write through that
            # identity via gcloud's global --account, without touching the developer's default gcloud login.
            _sa = os.environ.get("TM_SINK_SA", "").strip()
            _cmd = ["gcloud", "storage", "cp"] + (["--account", _sa] if _sa else []) + \
                   ["--if-generation-match=0", "-", f"gs://{bucket}/{key}"]
            r = subprocess.run(_cmd, input=payload, capture_output=True, timeout=20)
            if r.returncode == 0:
                return f"gs://{bucket}/{key}"
        except Exception:
            pass
    try:
        d = os.path.expanduser("~/.provenance/consults")
        os.makedirs(d, exist_ok=True)
        p = os.path.join(d, rec["id"] + ".json")
        with open(p, "wb") as f:
            f.write(payload)
        return p
    except Exception:
        return "(unlogged)"


def do_search(args) -> str:
    args = args or {}
    query = str(args.get("query", "")).strip()
    trace = args.get("trace")
    try:
        limit = max(1, min(10, int(args.get("max_results") or 5)))
    except Exception:
        limit = 5
    src = load_sources()
    allsrc = src.get("sources", []) if isinstance(src.get("sources"), list) else []
    repos = [s for s in allsrc if s.get("type") == "repo"]
    refs = [s for s in allsrc if s.get("type") != "repo"]
    results = []
    for s in repos:
        loc = (s.get("locator") or "").replace("https://", "").replace("github.com/", "").strip("/")
        if not loc:
            continue
        results.extend(gh_code_search(query, loc, limit))
    rec = {
        "kind": "source-consultation", "id": uuid.uuid4().hex, "at": _now(),
        "query": query, "trace": trace, "tool": NAME,
        "searched": [{"name": s.get("name"), "type": s.get("type"), "locator": s.get("locator")} for s in allsrc],
        "results": results,
        "references": [{"name": s.get("name"), "type": s.get("type"), "locator": s.get("locator")} for s in refs],
    }
    where = log_consultation(rec)
    lines = [f"Searched {len(repos)} approved repo(s) for: {query!r}"]
    if results:
        lines.append("Code matches — cite these in the Sources: field:")
        for m in results:
            lines.append(f"  - {m.get('repo')}/{m.get('path')}   {m.get('url','')}")
    else:
        lines.append("No code matches (or code search is unavailable — set TM_GH_TOKEN or authenticate `gh`).")
    if refs:
        lines.append("Also consult these approved references:")
        for s in refs:
            lines.append(f"  - [{s.get('type')}] {s.get('name')}: {s.get('locator')}")
    lines.append(f"(consultation logged → {where})")
    return "\n".join(lines)


TOOLS = [
    {"name": "list_approved_sources",
     "description": ("Return the CURRENT approved/preferred sources for this regulated codebase and the "
                     "priority order to use them. Read fresh from the central list."),
     "inputSchema": {"type": "object", "properties": {}, "additionalProperties": False}},
    {"name": "search_approved_sources",
     "description": ("Search the approved sources (code search across approved repos; other approved refs "
                     "are surfaced to consult) for a query, and RECORD the consultation to the audit sink. "
                     "Use this to find sanctioned material and cite what you draw from. Pass the current "
                     "work-item trace id so the consultation binds to the code."),
     "inputSchema": {"type": "object", "properties": {
         "query": {"type": "string", "description": "what you're looking for"},
         "trace": {"type": "string", "description": "current trace id (optional but recommended)"},
         "max_results": {"type": "integer", "description": "max code matches per repo (1-10, default 5)"}},
         "required": ["query"], "additionalProperties": False}},
]


def handle(method, params):
    if method == "initialize":
        pv = (params or {}).get("protocolVersion") or DEFAULT_PROTOCOL
        return {"protocolVersion": pv, "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": NAME, "version": VERSION}}
    if method == "ping":
        return {}
    if method == "tools/list":
        return {"tools": TOOLS}
    if method == "tools/call":
        p = params or {}
        name = p.get("name")
        if name == "list_approved_sources":
            return {"content": [{"type": "text", "text": json.dumps(load_sources(), indent=2)}], "isError": False}
        if name == "search_approved_sources":
            return {"content": [{"type": "text", "text": do_search(p.get("arguments"))}], "isError": False}
        return {"content": [{"type": "text", "text": f"unknown tool: {name}"}], "isError": True}
    raise KeyError(method)


def main():
    out = sys.stdout
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
        except Exception:
            continue
        mid = msg.get("id")
        if mid is None:
            continue
        try:
            resp = {"jsonrpc": "2.0", "id": mid, "result": handle(msg.get("method", ""), msg.get("params"))}
        except KeyError as e:
            resp = {"jsonrpc": "2.0", "id": mid, "error": {"code": -32601, "message": f"method not found: {e}"}}
        except Exception as e:
            resp = {"jsonrpc": "2.0", "id": mid, "error": {"code": -32603, "message": f"internal error: {e}"}}
        out.write(json.dumps(resp) + "\n")
        out.flush()


if __name__ == "__main__":
    main()
