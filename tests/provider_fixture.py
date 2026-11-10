"""Deterministic subprocess fixture; never accesses the network."""
import json
import sys
import time

track = json.loads(sys.argv[1])
time.sleep(.2)
print(json.dumps({"state": "ready", "synced": True, "source": "Test",
                  "lines": [{"at": 0, "text": track["title"]}]}))
