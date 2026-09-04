# PROVENANCE-BEGIN: BOILERPLATE  Agent: claude-code/claude-sonnet-5  Trace: T-srcdemo
#   Sources: https://docs.python.org/3/library/unittest.mock.html  Retrieved: 2026-09-04
import json
import os
import sys
import unittest
import urllib.error
from unittest.mock import MagicMock, patch

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))

import http_util  # noqa: E402


def _make_response(status=200, body=b"ok"):
    resp = MagicMock()
    resp.getcode.return_value = status
    resp.read.return_value = body
    resp.headers = {}
    cm = MagicMock()
    cm.__enter__.return_value = resp
    cm.__exit__.return_value = False
    return cm


class GetWithRetryTests(unittest.TestCase):
    @patch("http_util.urllib.request.urlopen")
    def test_success_first_try_returns_body(self, mock_urlopen):
        mock_urlopen.return_value = _make_response(200, b"payload")
        result = http_util.get_with_retry("http://example.test/x")
        self.assertEqual(result, b"payload")
        mock_urlopen.assert_called_once()

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_retries_on_url_error_then_succeeds(self, mock_urlopen, mock_sleep):
        mock_urlopen.side_effect = [
            urllib.error.URLError("boom"),
            _make_response(200, b"ok-after-retry"),
        ]
        result = http_util.get_with_retry("http://example.test/x", max_attempts=3)
        self.assertEqual(result, b"ok-after-retry")
        self.assertEqual(mock_urlopen.call_count, 2)
        mock_sleep.assert_called_once()

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_exhausts_attempts_raises_last_exception(self, mock_urlopen, mock_sleep):
        err = urllib.error.URLError("persistent failure")
        mock_urlopen.side_effect = [err, err, err]
        with self.assertRaises(urllib.error.URLError):
            http_util.get_with_retry("http://example.test/x", max_attempts=3)
        self.assertEqual(mock_urlopen.call_count, 3)
        self.assertEqual(mock_sleep.call_count, 2)

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_5xx_status_is_retried_and_eventually_raises(self, mock_urlopen, mock_sleep):
        mock_urlopen.return_value = _make_response(503, b"")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            http_util.get_with_retry("http://example.test/x", max_attempts=2)
        self.assertEqual(ctx.exception.code, 503)
        self.assertEqual(mock_urlopen.call_count, 2)

    @patch("http_util.time.sleep")
    @patch("http_util.random.uniform")
    @patch("http_util.urllib.request.urlopen")
    def test_jitter_true_uses_random_uniform_for_delay(
        self, mock_urlopen, mock_uniform, mock_sleep
    ):
        mock_uniform.return_value = 0.25
        mock_urlopen.side_effect = [
            urllib.error.URLError("boom"),
            _make_response(200, b"ok"),
        ]
        http_util.get_with_retry(
            "http://example.test/x", max_attempts=3, base_delay=1.0, jitter=True
        )
        mock_uniform.assert_called_once_with(0, 1.0)
        mock_sleep.assert_called_once_with(0.25)

    @patch("http_util.time.sleep")
    @patch("http_util.random.uniform")
    @patch("http_util.urllib.request.urlopen")
    def test_jitter_false_uses_exact_backoff_delay(
        self, mock_urlopen, mock_uniform, mock_sleep
    ):
        mock_urlopen.side_effect = [
            urllib.error.URLError("boom"),
            _make_response(200, b"ok"),
        ]
        http_util.get_with_retry(
            "http://example.test/x", max_attempts=3, base_delay=2.0, jitter=False
        )
        mock_uniform.assert_not_called()
        mock_sleep.assert_called_once_with(2.0)

    @patch("http_util.urllib.request.urlopen")
    def test_timeout_error_is_retried(self, mock_urlopen):
        mock_urlopen.side_effect = TimeoutError("timed out")
        with patch("http_util.time.sleep"):
            with self.assertRaises(TimeoutError):
                http_util.get_with_retry("http://example.test/x", max_attempts=1)


class PutWithRetryTests(unittest.TestCase):
    @patch("http_util.urllib.request.urlopen")
    def test_success_sends_put_with_json_body_and_headers(self, mock_urlopen):
        mock_urlopen.return_value = _make_response(200, b"created")
        payload = {"name": "widget", "count": 3}

        result = http_util.put_with_retry("http://example.test/items/1", payload)

        self.assertEqual(result, b"created")
        mock_urlopen.assert_called_once()
        sent_request = mock_urlopen.call_args[0][0]
        self.assertEqual(sent_request.get_method(), "PUT")
        self.assertEqual(sent_request.full_url, "http://example.test/items/1")
        self.assertEqual(json.loads(sent_request.data), payload)
        self.assertEqual(sent_request.headers.get("Content-type"), "application/json")

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_retries_on_url_error_then_succeeds(self, mock_urlopen, mock_sleep):
        mock_urlopen.side_effect = [
            urllib.error.URLError("boom"),
            _make_response(200, b"ok-after-retry"),
        ]
        result = http_util.put_with_retry(
            "http://example.test/items/1", {"a": 1}, max_attempts=3
        )
        self.assertEqual(result, b"ok-after-retry")
        self.assertEqual(mock_urlopen.call_count, 2)

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_exhausts_attempts_raises_last_exception(self, mock_urlopen, mock_sleep):
        err = urllib.error.URLError("persistent failure")
        mock_urlopen.side_effect = [err, err]
        with self.assertRaises(urllib.error.URLError):
            http_util.put_with_retry(
                "http://example.test/items/1", {"a": 1}, max_attempts=2
            )
        self.assertEqual(mock_urlopen.call_count, 2)

    @patch("http_util.time.sleep")
    @patch("http_util.urllib.request.urlopen")
    def test_5xx_status_is_retried_and_eventually_raises(self, mock_urlopen, mock_sleep):
        mock_urlopen.return_value = _make_response(500, b"")
        with self.assertRaises(urllib.error.HTTPError) as ctx:
            http_util.put_with_retry(
                "http://example.test/items/1", {"a": 1}, max_attempts=2
            )
        self.assertEqual(ctx.exception.code, 500)


if __name__ == "__main__":
    unittest.main()
# PROVENANCE-END: BOILERPLATE
