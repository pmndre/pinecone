# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets>=13", "sounddevice", "numpy"]
# ///
"""Talk to a voice service of Pinecone (a full-duplex model such as Sophon) with this computer's microphone and speakers.

    PINECONE_TOKEN=pc-... uv run talk.py --url http://your-mac:8080 --service sophon

It connects through the scheduler (/scheduler/connect/<service>), which loads the service if needed and holds it while
the conversation is open. The audio is raw PCM16 mono at 24 kHz both ways; text frames are the service's events, and
{"type": "interrupt"} means "stop playing now" (you spoke over the reply). Use headphones if you can: the service
cancels the echo of its own voice, but a laptop's speakers right next to its microphone are hard.

Ctrl+C ends the conversation. --list shows the audio devices, --in and --out pick them."""
import argparse, asyncio, json, os, re, sys, threading
from pathlib import Path

import numpy as np
import sounddevice as sd
import websockets

RATE, FRAME = 24000, 480  # 20 ms


class Speaker:
    """What the service said, played as it comes in; cleared at once when it is interrupted."""

    def __init__(self):
        self.buf, self.lock = bytearray(), threading.Lock()

    def add(self, pcm):
        with self.lock:
            self.buf.extend(pcm)

    def clear(self):
        with self.lock:
            self.buf.clear()

    def callback(self, out, frames, _time, _status):
        n = frames * 2
        with self.lock:
            chunk = bytes(self.buf[:n]); del self.buf[:n]
        out[:] = np.frombuffer(chunk.ljust(n, b"\0"), "<i2").reshape(-1, 1)


def token(url):
    if os.environ.get("PINECONE_TOKEN"):
        return os.environ["PINECONE_TOKEN"]
    key = Path(os.environ.get("PINECONE_HOME", Path.home() / ".pinecone")) / "internal-key.txt"
    if key.exists() and any(h in url for h in ("localhost", "127.0.0.1", "[::1]")):  # on the Mac that runs Pinecone
        return key.read_text().strip()
    sys.exit("set PINECONE_TOKEN to an access token (make one in the Pinecone app's Settings)")


async def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--url", default=os.environ.get("PINECONE_URL", "http://localhost:8080"), help="the scheduler")
    p.add_argument("--service", default="sophon", help="the voice service, as named in the config")
    p.add_argument("--in", dest="mic", default=None, help="input device (number or part of its name)")
    p.add_argument("--out", dest="spk", default=None, help="output device")
    p.add_argument("--list", action="store_true", help="list the audio devices and stop")
    p.add_argument("--events", action="store_true", help="print every event the service sends")
    a = p.parse_args()
    if a.list:
        print(sd.query_devices()); return
    device = lambda d: int(d) if d and d.isdigit() else d
    url = a.url.rstrip("/").replace("http", "ws", 1) + f"/scheduler/connect/{a.service}"
    loop, mic, speaker = asyncio.get_running_loop(), asyncio.Queue(maxsize=100), Speaker()

    def heard(data, _frames, _time, _status):
        loop.call_soon_threadsafe(lambda b=bytes(data): mic.full() or mic.put_nowait(b))

    print(f"connecting to {a.service} (it is loaded first if it is not running)...", flush=True)
    try:
        ws = await websockets.connect(url, additional_headers={"Authorization": f"Bearer {token(a.url)}"},
                                      open_timeout=600, close_timeout=2, max_size=1 << 24)
    except websockets.InvalidStatus as e:
        body = e.response.body.decode("utf-8", "replace") if e.response.body else ""
        try:
            body = json.loads(body)["error"]["message"]
        except (ValueError, KeyError, TypeError):
            pass
        sys.exit(f"refused ({e.response.status_code}): {body}")
    except (OSError, websockets.WebSocketException) as e:
        sys.exit(f"could not connect to {url}: {e}")

    with sd.RawInputStream(RATE, FRAME, device=device(a.mic), channels=1, dtype="int16", callback=heard), \
         sd.OutputStream(RATE, FRAME, device=device(a.spk), channels=1, dtype="int16", callback=speaker.callback):
        print("talk now (Ctrl+C to stop)", flush=True)

        async def send():
            while True:
                await ws.send(await mic.get())

        async def receive():
            async for m in ws:
                if isinstance(m, bytes):
                    speaker.add(m); continue
                e = json.loads(m)
                kind = e.get("type") or e.get("ev")
                if kind == "interrupt":
                    speaker.clear()
                if a.events:
                    print(m, flush=True)
                elif kind == "reply_done" and e.get("text"):
                    text = re.sub(r"</?\w+>", "", e["text"])  # stress marks such as <strong>, spoken, not shown
                    print(f"{a.service}: {text}" + (" (cut off)" if e.get("cancelled") else ""), flush=True)
                elif kind == "disconnect":
                    print("(the service ended the conversation)", flush=True)

        tasks = [asyncio.ensure_future(send()), asyncio.ensure_future(receive())]
        try:
            await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED)
        finally:
            for t in tasks:
                t.cancel()
            await ws.close()
        if ws.close_code not in (None, 1000):
            print(f"closed: {ws.close_code} {ws.close_reason}", flush=True)


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
