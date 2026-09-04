# PROVENANCE-BEGIN: AI-DRAFTED  Agent: claude-code/claude-opus-4-7  Trace: T-srcdemo
#   Sources: github.com/urllib3/urllib3@546f5d2419ee1331cc2a22cdf80e6bad46e92dbc#src/urllib3/util/retry.py  Retrieved: 2026-09-03
import random
import time
import urllib.error
import urllib.request


def get_with_retry(
    url,
    max_attempts=5,
    base_delay=0.5,
    max_delay=30.0,
    jitter=True,
    timeout=10.0,
):
    last_exc = None
    for attempt in range(max_attempts):
        try:
            with urllib.request.urlopen(url, timeout=timeout) as resp:
                status = resp.getcode()
                if 500 <= status < 600:
                    raise urllib.error.HTTPError(
                        url, status, "server error", resp.headers, None
                    )
                return resp.read()
        except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as exc:
            last_exc = exc
            if attempt == max_attempts - 1:
                break
            delay = min(max_delay, base_delay * (2 ** attempt))
            if jitter:
                delay = random.uniform(0, delay)
            time.sleep(delay)
    raise last_exc
# PROVENANCE-END: AI-DRAFTED
