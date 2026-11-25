"""A stand-in model server for scheduler tests."""
import asyncio, sys
from aiohttp import web
name, port = sys.argv[1], int(sys.argv[2])
async def health(r): return web.json_response({"status": "ok"})
async def chat(r):
    j = await r.json()
    if "remember" in j: memory[int(j.get("slot", 0))] = j["remember"]
    if j.get("stream"):
        resp = web.StreamResponse(headers={"Content-Type": "text/event-stream"}); await resp.prepare(r)
        for i in range(3):
            await resp.write(f'data: {{"from":"{name}","i":{i}}}\n\n'.encode()); await asyncio.sleep(float(j.get("delay", 0.2)))
        await resp.write(b"data: [DONE]\n\n"); return resp
    await asyncio.sleep(float(j.get("delay", 0)))
    return web.json_response({"from": name})
# What a llama.cpp server keeps per slot and can write to disk (--slot-save-path): here, one word per slot.
import json, os
save_dir = sys.argv[sys.argv.index("--slot-save-path") + 1] if "--slot-save-path" in sys.argv else None
# Reading a large slot back takes seconds on a real server: --slow-restore <seconds> makes it take that long here.
slow = float(sys.argv[sys.argv.index("--slow-restore") + 1]) if "--slow-restore" in sys.argv else 0
memory = {0: "", 1: ""}
async def slots(r): return web.json_response([{"id": i, "remembers": m, "save_dir": save_dir} for i, m in memory.items()])
async def slot(r):
    i, action, name = int(r.match_info["id"]), r.query.get("action"), (await r.json()).get("filename")
    if save_dir is None: return web.json_response({"error": "started without --slot-save-path"}, status=501)
    path = os.path.join(save_dir, name)
    if action == "save":
        with open(path, "w") as f: f.write(memory[i])
        return web.json_response({"id_slot": i, "filename": name, "n_saved": len(memory[i]), "n_written": len(memory[i])})
    if action == "restore":
        await asyncio.sleep(slow)
        with open(path) as f: memory[i] = f.read()
        return web.json_response({"id_slot": i, "filename": name, "n_restored": len(memory[i]), "n_read": len(memory[i])})
    return web.json_response({"error": "unknown action"}, status=400)
# A WebSocket, as a voice service has: echoes what it gets with its name, says where it was reached, and on "bye" closes
# with a code of its own (4001) and a reason.
async def ws(r):
    s = web.WebSocketResponse(); await s.prepare(r)
    await s.send_str(f"{name} at {r.path_qs}")
    async for m in s:
        if m.type == web.WSMsgType.TEXT and m.data == "bye": await s.close(code=4001, message=b"asked to"); break
        if m.type == web.WSMsgType.TEXT: await s.send_str(f"{name}: {m.data}")
        elif m.type == web.WSMsgType.BINARY: await s.send_bytes(m.data[::-1])
    return s
app = web.Application(); app.router.add_get("/health", health); app.router.add_post("/v1/chat/completions", chat)
app.router.add_get("/", ws); app.router.add_get("/talk", ws)
app.router.add_get("/slots", slots); app.router.add_post("/slots/{id}", slot)
web.run_app(app, host="127.0.0.1", port=port, print=None)
