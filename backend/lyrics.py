#!/usr/bin/env python3
"""Small, bounded lyrics client. Input and output are JSON; no shell commands."""
from __future__ import annotations

import json
import math
import re
import signal
import sys
import time
import unicodedata
from difflib import SequenceMatcher
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode
from urllib.request import HTTPRedirectHandler, Request, build_opener
import zlib

LIMIT = 1_048_576
DECODED_LIMIT = 2_097_152
OUTPUT_LIMIT = 524_288
TEXT_LIMIT = 65_536
LINE_LIMIT = 2_000
LINE_TEXT_LIMIT = 2_048
RESULT_LIMIT = 50
STAMP = re.compile(r"\[(\d{1,3}):([0-5]\d)(?:[.:](\d{1,3}))?\]")
VARIANTS = {"live", "remix", "acoustic", "instrumental", "karaoke", "demo", "cover"}


def normalized(value):
    value = unicodedata.normalize("NFC", str(value or "")).casefold()
    return " ".join("".join(c if c.isalnum() or unicodedata.category(c).startswith("M")
                            or c in "\u200c\u200d" else " " for c in value).split())


def parse_lrc(text):
    if len(text) > TEXT_LIMIT:
        raise ValueError("Lyrics are too long")
    offset = re.search(r"\[offset:([+-]?\d+)\]", text, re.I)
    shift = int(offset[1]) / 1000 if offset else 0
    rows = []
    for line in text.splitlines():
        stamps = list(STAMP.finditer(line))
        if not stamps:
            continue
        words = STAMP.sub("", line).strip()
        # Blank timed lines are meaningful instrumental gaps.
        for stamp in stamps:
            if len(rows) >= LINE_LIMIT or len(words) > LINE_TEXT_LIMIT:
                raise ValueError("Too many or oversized lyric cues")
            fraction = float("0." + stamp[3]) if stamp[3] else 0
            rows.append({"at": max(0, int(stamp[1]) * 60 + int(stamp[2]) + fraction + shift),
                         "text": words})
    rows.sort(key=lambda row: row["at"])
    # Some files have simultaneous translation lines: keep both on one cue.
    merged = []
    for row in rows:
        if merged and merged[-1]["at"] == row["at"]:
            if row["text"] and row["text"] != merged[-1]["text"]:
                merged[-1]["text"] += "\n" + row["text"]
                if len(merged[-1]["text"]) > LINE_TEXT_LIMIT:
                    raise ValueError("Merged cue is too large")
        else:
            merged.append(row)
    return merged


def result_from_record(record, source="LRCLIB"):
    if not isinstance(record, dict):
        return None
    if record.get("instrumental") is True:
        return {"state": "instrumental", "lines": [], "synced": False, "source": source}
    synced = record.get("syncedLyrics")
    lines = parse_lrc(synced) if isinstance(synced, str) else []
    if lines and any(row["text"] for row in lines):
        return {"state": "ready", "lines": lines, "synced": True, "source": source}
    plain = record.get("plainLyrics")
    if isinstance(plain, str) and plain.strip():
        if len(plain) > TEXT_LIMIT:
            raise ValueError("Lyrics are too long")
        plain_lines = plain.strip().splitlines()
        if len(plain_lines) > LINE_LIMIT or any(len(line) > LINE_TEXT_LIMIT for line in plain_lines):
            raise ValueError("Too many or oversized lyric lines")
        return {"state": "ready", "lines": [{"at": -1, "text": s} for s in plain.strip().splitlines()],
                "synced": False, "source": source}
    return None


def rank(record, track):
    if not isinstance(record, dict):
        return -1
    for key in ("trackName", "artistName", "albumName"):
        field = record.get(key, "")
        if key == "albumName" and field is None:
            continue
        if not isinstance(field, str) or len(field) > 500:
            return -1
    wanted, candidate = normalized(track["title"]), normalized(record.get("trackName"))
    if not candidate or (set(wanted.split()) & VARIANTS) != (set(candidate.split()) & VARIANTS):
        return -1
    title_score = SequenceMatcher(None, wanted, candidate).ratio()
    artist_score = SequenceMatcher(None, normalized(track["artist"]), normalized(record.get("artistName"))).ratio()
    if title_score < .9 or artist_score < .65:
        return -1
    try:
        length = float(record.get("duration", 0))
        delta = abs(length - track["duration"])
        if track["duration"] > 0 and (not math.isfinite(length) or length <= 0 or delta > 8):
            return -1
    except (ValueError, TypeError):
        return -1
    return title_score * 4 + artist_score * 2 + (normalized(record.get("albumName")) == normalized(track["album"])) + bool(record.get("syncedLyrics")) * .2


class NoRedirects(HTTPRedirectHandler):
    def http_error_302(self, req, fp, code, msg, headers):
        fp.close()
        raise ValueError("Provider redirected the request")

    http_error_301 = http_error_303 = http_error_307 = http_error_308 = http_error_302

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise ValueError("Provider redirected the request")


class RateLimited(Exception):
    def __init__(self, delay):
        self.delay = delay


def fetch_json(url):
    request = Request(url, headers={
        "User-Agent": "SingWithOmarchy/0.1 (https://github.com/akashanil-dev/sing-with-omarchy)",
        "Accept": "application/json",
        "Accept-Encoding": "identity",
    })
    try:
        with build_opener(NoRedirects()).open(request, timeout=5) as response:
            body = response.read(LIMIT + 1)
            if len(body) > LIMIT:
                raise ValueError("Provider response too large")
            encoding = response.headers.get("Content-Encoding", "identity").lower().strip()
            if encoding == "gzip":
                decoder = zlib.decompressobj(16 + zlib.MAX_WBITS)
                body = decoder.decompress(body, DECODED_LIMIT + 1)
                if len(body) > DECODED_LIMIT or not decoder.eof or decoder.unused_data:
                    raise ValueError("Invalid or oversized compressed response")
            elif encoding != "identity":
                raise ValueError("Unsupported response encoding")
            return json.loads(body)
    except HTTPError as error:
        error.close()
        if error.code == 404:
            return None
        if error.code in (429, 503):
            try:
                delay = max(60, int(error.headers.get("Retry-After", "60")))
            except ValueError:
                from email.utils import parsedate_to_datetime
                try:
                    delay = max(60, math.ceil(parsedate_to_datetime(error.headers["Retry-After"]).timestamp() - time.time()))
                except (ValueError, TypeError, KeyError, OverflowError):
                    delay = 300
            raise RateLimited(delay) from error
        raise


def lookup(track, fetch=fetch_json, pause=time.sleep):
    if not track["title"] or not track["artist"]:
        return {"state": "missing", "message": "The player needs to provide both a title and artist.", "lines": []}
    failures = 0
    params = {"track_name": track["title"], "artist_name": track["artist"]}
    if track["album"]:
        params["album_name"] = track["album"]
    if 1 <= track["duration"] <= 3600:
        params["duration"] = track["duration"]
    urls = ["https://lrclib.net/api/get?" + urlencode(params),
            "https://lrclib.net/api/search?" + urlencode({k: params[k] for k in ("track_name", "artist_name")}),
            "https://api.lyrics.ovh/v1/" + quote(track["artist"], safe="") + "/" + quote(track["title"], safe="")]
    for index, url in enumerate(urls):
        if index:
            pause(.25)
        try:
            data = fetch(url)
            if data is None:
                continue
            if index == 2:
                result = result_from_record({"plainLyrics": data.get("lyrics")}, "Lyrics.ovh") if isinstance(data, dict) else None
                if result:
                    return result
                continue
            candidates = data if isinstance(data, list) else [data]
            if len(candidates) > RESULT_LIMIT:
                raise ValueError("Too many search results")
            scored = [(rank(candidate, track), candidate) for candidate in candidates]
            for score, candidate in sorted(scored, key=lambda pair: pair[0], reverse=True):
                if score >= 0:
                    result = result_from_record(candidate)
                    if result:
                        return result
        except RateLimited as error:
            return {"state": "error", "message": "Provider is busy. Try again after the countdown.",
                    "retryAfter": error.delay, "lines": []}
        except (URLError, OSError, ValueError, TypeError, RecursionError, zlib.error):
            failures += 1
    return {"state": "error" if failures else "missing", "lines": [],
            "message": "Could not reach a lyrics provider. Check your connection and retry." if failures else "No matching lyrics found for this recording."}


def read_track(raw):
    if not isinstance(raw, dict):
        raise ValueError("Expected a track object")
    if any(not isinstance(raw.get(key, ""), str) or len(raw.get(key, "")) > 500
           for key in ("title", "artist", "album")):
        raise ValueError("Invalid metadata field")
    track = {key: raw.get(key, "").strip() for key in ("title", "artist", "album")}
    length = float(raw.get("duration", 0) or 0)
    track["duration"] = length if math.isfinite(length) and length > 0 else 0
    return track


class LookupExpired(Exception):
    pass


def expire(signum, frame):
    raise LookupExpired()


def encode_result(output):
    body = json.dumps(output, ensure_ascii=False).encode("utf-8")
    if len(body) > OUTPUT_LIMIT:
        return b'{"state":"error","message":"The lyrics response is too large.","lines":[]}'
    return body


if __name__ == "__main__":
    signal.signal(signal.SIGALRM, expire)
    signal.setitimer(signal.ITIMER_REAL, 20)
    try:
        raw = sys.stdin.buffer.readline(16_386)
        if not raw.endswith(b"\n") or len(raw) > 16_385:
            raise ValueError("Expected a bounded JSON line on stdin")
        output = lookup(read_track(json.loads(raw)))
    except LookupExpired:
        output = {"state": "error", "message": "The lyrics request timed out. Try again.", "lines": []}
    except (ValueError, TypeError, RecursionError):
        output = {"state": "error", "message": "Invalid track metadata.", "lines": []}
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
    sys.stdout.buffer.write(encode_result(output) + b"\n")
