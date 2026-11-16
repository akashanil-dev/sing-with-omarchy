"""Run the lyrics helper behind private pipes, an output cap and a hard deadline."""
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

INPUT_LIMIT = 16_384
OUTPUT_LIMIT = 524_288


def failure(message):
    return json.dumps({"state": "error", "message": message, "lines": []}).encode()


def run(helper, payload, seconds=22, output_limit=OUTPUT_LIMIT):
    if len(payload) > INPUT_LIMIT:
        return failure("Track metadata is too large.")
    process = subprocess.Popen([sys.executable, str(helper)], stdin=subprocess.PIPE,
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                               start_new_session=True)
    until = time.monotonic() + seconds
    output = bytearray()
    pending = memoryview(payload + b"\n")
    try:
        with selectors.DefaultSelector() as selector:
            os.set_blocking(process.stdin.fileno(), False)
            os.set_blocking(process.stdout.fileno(), False)
            selector.register(process.stdin, selectors.EVENT_WRITE)
            selector.register(process.stdout, selectors.EVENT_READ)
            while selector.get_map():
                remaining = until - time.monotonic()
                if remaining <= 0:
                    return failure("The lyrics request timed out. Try again.")
                for key, _ in selector.select(min(remaining, .1)):
                    if key.fileobj is process.stdin:
                        try:
                            written = os.write(key.fd, pending[:4096])
                            pending = pending[written:]
                        except BrokenPipeError:
                            pending = memoryview(b"")
                        if not pending:
                            selector.unregister(key.fileobj)
                            process.stdin.close()
                    else:
                        chunk = os.read(key.fd, min(16384, output_limit + 1 - len(output)))
                        if not chunk:
                            selector.unregister(key.fileobj)
                        else:
                            output.extend(chunk)
                            if len(output) > output_limit:
                                return failure("The lyrics response is too large.")
            try:
                status = process.wait(timeout=max(.001, until - time.monotonic()))
            except subprocess.TimeoutExpired:
                return failure("The lyrics request timed out. Try again.")
            if status != 0 or not output:
                return failure("The lyrics helper could not finish. Try again.")
            return bytes(output)
    finally:
        # Also reap children that retained a pipe after their parent exited.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        process.wait()
        process.stdin.close()
        process.stdout.close()


if __name__ == "__main__":
    def interrupted(signum, frame):
        raise InterruptedError()
    signal.signal(signal.SIGTERM, interrupted)
    try:
        payload = sys.stdin.buffer.readline(INPUT_LIMIT + 2)
        if not payload.endswith(b"\n") or len(payload) > INPUT_LIMIT + 1:
            answer = failure("Invalid track metadata.")
        else:
            helper = sys.argv[1] if len(sys.argv) == 2 else Path(__file__).with_name("lyrics.py")
            answer = run(helper, payload[:-1])
    except (OSError, ValueError):
        answer = failure("The lyrics helper could not start.")
    sys.stdout.buffer.write(answer + b"\n")
