import gzip
import io
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
from urllib.request import HTTPSHandler, build_opener
from urllib.response import addinfourl

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
import lyrics
import worker


class Response(io.BytesIO):
    def __init__(self, data, encoding="identity"):
        super().__init__(data)
        self.headers = {"Content-Encoding": encoding}


class Boundaries(unittest.TestCase):
    def fetch(self, body, encoding="identity"):
        response = Response(body, encoding)
        with patch.object(lyrics, "build_opener") as opener:
            opener.return_value.open.return_value = response
            return lyrics.fetch_json("https://lrclib.net/api/get")

    def test_wire_and_gzip_limits(self):
        for body, encoding in [(b"x" * (lyrics.LIMIT + 1), "identity"),
                               (gzip.compress(b"x" * (lyrics.DECODED_LIMIT + 1)), "gzip")]:
            with self.subTest(encoding=encoding), self.assertRaises(ValueError):
                self.fetch(body, encoding)
        self.assertEqual(self.fetch(gzip.compress(b'{"ok":true}'), "gzip"), {"ok": True})
        with self.assertRaises(ValueError):
            self.fetch(gzip.compress(b"{}") + gzip.compress(b"{}"), "gzip")

    def test_redirect_body_never_read_by_real_opener(self):
        class Trap(io.BytesIO):
            def read(self, *args):
                raise AssertionError("Redirect body was read")
        for code in (301, 302, 303, 307, 308):
            with self.subTest(code=code):
                body = Trap(b"unbounded body")
                class FakeTLS(HTTPSHandler):
                    def https_open(self, request):
                        response = addinfourl(body, {"Location": "https://lrclib.net/elsewhere"}, request.full_url, code)
                        response.msg = "Redirect"
                        return response
                opener = build_opener(lyrics.NoRedirects(), FakeTLS())
                with self.assertRaises(ValueError):
                    opener.open("https://lrclib.net/api/get")
                self.assertTrue(body.closed)

    def test_cue_amplification_and_plain_line_limits(self):
        for text in ("[00:01]" * (lyrics.LINE_LIMIT + 1) + "word",
                     "[00:01]" + "x" * (lyrics.LINE_TEXT_LIMIT + 1),
                     "[00:01]" + "a" * 1500 + "\n[00:01]" + "b" * 1500):
            with self.subTest(length=len(text)), self.assertRaises(ValueError):
                lyrics.parse_lrc(text)
        with self.assertRaises(ValueError):
            lyrics.result_from_record({"plainLyrics": "word\n" * (lyrics.LINE_LIMIT + 1)})

    def test_rank_rejects_oversized_remote_metadata(self):
        track = lyrics.read_track({"title": "Evening", "artist": "Someone"})
        self.assertEqual(lyrics.rank({"trackName": "Evening", "artistName": "a" * 10000}, track), -1)

    def test_output_serialization_cap(self):
        output = lyrics.encode_result({"state": "ready", "lines": [{"text": "x" * (lyrics.OUTPUT_LIMIT + 1)}]})
        self.assertLess(len(output), lyrics.OUTPUT_LIMIT)
        self.assertEqual(json.loads(output)["state"], "error")

    def fixture(self, code, payload=b'{}', **kwargs):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "fixture.py"
            path.write_text(code)
            return json.loads(worker.run(path, payload, **kwargs))

    def test_private_pipe_preserves_metadata_without_argv_leak(self):
        payload = json.dumps({"title": "Private song Ω"}).encode()
        answer = self.fixture('''import json, os, pathlib, sys
track = json.loads(sys.stdin.readline())
for pid in (os.getpid(), os.getppid()):
    assert track["title"].encode() not in pathlib.Path(f"/proc/{pid}/cmdline").read_bytes()
print(json.dumps({"state":"ready", "title":track["title"]}))
''', payload)
        self.assertEqual(answer["title"], "Private song Ω")

    def test_worker_caps_output_before_returning_it(self):
        answer = self.fixture('import sys\nsys.stdout.write("x" * 1000000)', output_limit=128)
        self.assertEqual(answer["state"], "error")
        self.assertIn("large", answer["message"])

    def test_trickling_process_has_total_deadline(self):
        before = time.monotonic()
        answer = self.fixture('''import signal, sys, time
signal.signal(signal.SIGTERM, signal.SIG_IGN)
while True:
    sys.stdout.write("x"); sys.stdout.flush(); time.sleep(.02)
''', seconds=.2)
        self.assertIn("timed out", answer["message"])
        self.assertLess(time.monotonic() - before, 2)

    def test_closed_stdout_does_not_evade_deadline(self):
        answer = self.fixture('import os,time\nos.close(1)\ntime.sleep(10)', seconds=.2)
        self.assertIn("timed out", answer["message"])

    def test_failed_helper_is_retryable(self):
        answer = self.fixture('raise RuntimeError("private metadata")')
        self.assertEqual(answer["state"], "error")
        self.assertNotIn("private metadata", json.dumps(answer))


if __name__ == "__main__":
    unittest.main()
