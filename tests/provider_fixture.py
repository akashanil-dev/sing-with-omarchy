"""Deterministic subprocess fixture; never accesses the network."""
import json
import sys
import time

track = json.loads(sys.stdin.readline())
time.sleep(.2)
print(json.dumps({"state": "ready", "synced": True, "source": "Test",
                  "lines": [{"at": 0, "text": track["title"]}]}))
