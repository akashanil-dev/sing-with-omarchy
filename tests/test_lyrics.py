import json
import sys
import unittest
from pathlib import Path
from urllib.error import URLError

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "backend"))
import lyrics


class LyricsTests(unittest.TestCase):
    def setUp(self):
        self.track = lyrics.read_track({"title": "Evening", "artist": "Someone", "duration": 120})
        self.record = {"trackName": "Evening", "artistName": "Someone", "duration": 121,
                       "syncedLyrics": "[00:05.50]First\n[00:10]Second"}

    def lookup(self, responses):
        self.urls = []
        def fetch(url):
            self.urls.append(url)
            response = responses.pop(0)
            if isinstance(response, Exception):
                raise response
            return response
        return lyrics.lookup(self.track, fetch=fetch, pause=lambda _: None)

    def test_lrc_multiple_stamps_translation_gaps_offset(self):
        rows = lyrics.parse_lrc("[offset:-500]\n[00:02.50][00:05]Hello\n[00:02.50]Translation\n[00:08]\n[ar:Someone]")
        self.assertEqual(rows, [{"at": 2, "text": "Hello\nTranslation"}, {"at": 4.5, "text": "Hello"}, {"at": 7.5, "text": ""}])

    def test_unicode_joiners_remain_distinct(self):
        self.assertNotEqual(lyrics.normalized("ന്\u200d"), lyrics.normalized("ന്"))
        self.assertEqual(lyrics.normalized("Été!"), lyrics.normalized("E\u0301te\u0301"))

    def test_exact_match_stops_requests(self):
        result = self.lookup([self.record])
        self.assertEqual(result["state"], "ready")
        self.assertTrue(result["synced"])
        self.assertEqual(len(self.urls), 1)

    def test_wrong_artist_version_and_duration_rejected(self):
        for mutation in ({"artistName": "Another person"}, {"trackName": "Evening live"}, {"duration": 200}, {"duration": "NaN"}):
            with self.subTest(mutation=mutation):
                self.assertLess(lyrics.rank(self.record | mutation, self.track), 0)

    def test_search_fallback_chooses_matching_record(self):
        result = self.lookup([None, [self.record | {"duration": 500}, self.record]])
        self.assertTrue(result["synced"])
        self.assertEqual(len(self.urls), 2)

    def test_plain_provider_fallback(self):
        result = self.lookup([None, [], {"lyrics": "Words\nMore words"}])
        self.assertFalse(result["synced"])
        self.assertEqual(result["source"], "Lyrics.ovh")
        self.assertEqual(result["lines"][0]["at"], -1)

    def test_instrumental_does_not_query_fallback(self):
        result = self.lookup([self.record | {"instrumental": True}])
        self.assertEqual(result["state"], "instrumental")
        self.assertEqual(len(self.urls), 1)

    def test_bad_lrc_uses_plain_text(self):
        result = lyrics.result_from_record({"syncedLyrics": "[ar:metadata]", "plainLyrics": "<b>Literal words</b>"})
        self.assertFalse(result["synced"])
        self.assertEqual(result["lines"][0]["text"], "<b>Literal words</b>")

    def test_missing_and_network_failure_are_distinct(self):
        self.assertEqual(self.lookup([None, [], None])["state"], "missing")
        self.assertEqual(self.lookup([URLError("offline"), URLError("offline"), URLError("offline")])["state"], "error")

    def test_rate_limit_stops_provider_requests(self):
        result = self.lookup([lyrics.RateLimited(3600)])
        self.assertEqual(result["retryAfter"], 3600)
        self.assertEqual(len(self.urls), 1)

    def test_metadata_cannot_inject_url_path(self):
        self.track["artist"] = "A/B?x=y"
        self.lookup([None, [], None])
        self.assertIn("A%2FB%3Fx%3Dy", self.urls[-1])

    def test_missing_artist_avoids_lookup(self):
        self.track["artist"] = ""
        self.assertEqual(self.lookup([])["state"], "missing")
        self.assertFalse(self.urls)

    def test_invalid_and_oversized_metadata(self):
        self.assertEqual(lyrics.read_track({"title": "a" * 900, "duration": "nan"})["duration"], 0)
        self.assertEqual(len(lyrics.read_track({"title": "a" * 900})["title"]), 500)
        with self.assertRaises(ValueError):
            lyrics.read_track([])

    def test_no_redirects(self):
        with self.assertRaises(ValueError):
            lyrics.NoRedirects().redirect_request(None, None, 302, "", {}, "http://localhost/")


if __name__ == "__main__":
    unittest.main()
