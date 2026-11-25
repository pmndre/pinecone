"""WebSockets to a service through the scheduler (/scheduler/connect/<service>). Needs a scheduler that was started with
tests/config.json, like run.py; run it after run.py or on its own."""
import asyncio, sys
import aiohttp
B = "http://127.0.0.1:18080"; H = {"Authorization": "Bearer test-key"}
ok = True
def check(label, cond, extra=""):
    global ok; ok &= bool(cond); print(("PASS " if cond else "FAIL "), label, extra)
async def status(s):
    async with s.get(B + "/scheduler/status", headers=H) as r: return await r.json()
async def main():
    async with aiohttp.ClientSession() as s:
        async with s.get(B + "/scheduler/connect/svc") as r: check("no key is refused", r.status == 401)
        async with s.get(B + "/scheduler/connect/nope", headers=H) as r: check("unknown service is 404", r.status == 404)
        async with s.get(B + "/scheduler/connect/mid", headers=H) as r: check("a model is not a service", r.status == 404)
        async with s.get(B + "/scheduler/connect/svc", headers=H) as r: check("plain GET is told to use a WebSocket", r.status == 400)
        async with s.get(B + "/scheduler/connect/broken", headers=H) as r: check("only services", r.status == 404)

        ws = await s.ws_connect(B + "/scheduler/connect/svc/talk?x=1", headers=H, autoping=False)
        hello = await ws.receive_str()
        check("connects through, loading the service, path and query passed on", hello == "svc at /talk?x=1", hello)
        await ws.send_str("hi"); got = await ws.receive_str(); check("text both ways", got == "svc: hi", got)
        await ws.send_bytes(b"abc"); got = await ws.receive_bytes(); check("binary both ways", got == b"cba", str(got))
        await ws.ping(b"p1"); m = await ws.receive(); check("a ping reaches the service, its pong comes back", m.type == aiohttp.WSMsgType.PONG and m.data == b"p1", str(m.type))
        j = await status(s); svc = j["resources"]["svc"]
        check("the service is held while the socket is open", svc["state"] == "ready" and svc["active"] == 1, str(svc.get("active")))
        await asyncio.sleep(8)  # longer than svc's idle_stop_s (6)
        check("an open socket keeps the service from stopping", (await status(s))["resources"]["svc"]["state"] == "ready")
        await ws.close()
        await asyncio.sleep(0.5)
        check("closing lets the service go", (await status(s))["resources"]["svc"]["active"] == 0)

        ws = await s.ws_connect(B + "/scheduler/connect/svc", headers=H)
        hello = await ws.receive_str(); check("the root path by default", hello == "svc at /", hello)
        await ws.send_str("bye"); m = await ws.receive()
        check("the service's close code and reason reach the caller", m.type == aiohttp.WSMsgType.CLOSE and m.data == 4001 and m.extra == "asked to", f"{m.data} {m.extra!r}")
        await asyncio.sleep(0.5)
        check("and the service is let go", (await status(s))["resources"]["svc"]["active"] == 0)
    print("ALL PASS" if ok else "SOME FAILED")
    sys.exit(0 if ok else 1)
asyncio.run(main())
