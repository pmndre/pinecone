# API

[Setup](setup.md) · [Configuration](configuration.md) · [Media tools](tools.md) · [Clients](clients.md) · [API](api.md) · [The app](app.md) · [Operations](operations.md)

What the scheduler and the media server answer to over HTTP. Everything but the two `/health` paths wants `Authorization: Bearer <key>`: an access token, or for what is marked "own key only" the scheduler's own key.

## Scheduler (port 8080)

| Request | What it does |
|---|---|
| `GET /health` | No key needed. Says that the scheduler is up, and tells a caller on the same Mac where the key file is. |
| `/v1/...` | Passed to the model named in the request body's `"model"`. `GET /v1/models` lists them. |
| any other path | Passed to the language model that was used last (the llama.cpp web UI, `/props`, `/slots`); 503 when none is loaded. |
| `GET /scheduler/whoami` | `{"admin": true}` for the scheduler's own key, `false` for an access token. |
| `GET /scheduler/status` | Everything the app shows, as JSON: resources, queue, recent events, machine load, endpoints. |
| `POST /scheduler/acquire {"resource", "ttl_s", "who"}` | Take a lease on a service; answers `{"lease", "resource", "url", "ttl_s"}` once it is ready. `ttl_s` is 1 to 3600 seconds (600 if left out), `who` a name to show for the caller. A lease that is not renewed ends by itself. |
| `POST /scheduler/renew {"lease", "ttl_s"}`, `POST /scheduler/release {"lease"}` | Keep a lease for another `ttl_s`, or give it back. |
| `GET /scheduler/connect/<service>[/path]` | A WebSocket to a service, passed through both ways, to `/path` (or `/`) on it, with the query. The service is loaded first (the handshake waits) and held while the socket is open. Messages, pings and the close code go through unchanged; the key does not. 404 for a name that is not a service, 400 without a WebSocket handshake, 502 when the service does not take it. |
| `POST /scheduler/unload {"resource"}` | Unload something idle. |
| `GET /scheduler/config` | `{"config", "order", "env"}`: the config file, the order of its resources, and the entries of `.env`. Own key only. |
| `POST /scheduler/config {"patch": {...}, "env": {...}}` | Merge the patch into the file (null removes a key), check, save, apply; `env` sets or (null) removes entries of `.env`. Answers `{"ok", "changes"}`. Own key only. |
| `POST /scheduler/reload` | Read the config file again now. Own key only. |
| `GET /scheduler/tokens`, `POST /scheduler/mint`, `POST /scheduler/revoke` | Access tokens. Own key only. |
| `POST /scheduler/announce {"name", "url", "info"}` | Another service says where clients find it; listed under `endpoints` in the status for 3 minutes, so it is repeated. What is in `info` is listed with it (the media server sends its tools). Own key only. |

Nothing behind the scheduler can be reached without a key, and whatever changes something takes POST.

Each server's output goes to `~/.pinecone/logs/<name>.log`.

## Media server (port 8090)

| Request | What it does |
|---|---|
| `/mcp` | The MCP endpoint (streamable HTTP, stateless). Tools: the entries under `"tools"`, plus `upload_link`, `put_file`, `get_file` and `media_status`. Resources: `pinecone://files/<name>`. |
| `GET /health` | No key needed. The tools the server made, and any it left out with the reason. |
| `GET /files/<name>` | A result or uploaded file. With a key, or with the signature a tool answer's `url` carries. |
| `POST /upload?name=x.jpg` | Takes a file (raw body or a multipart `file` field). Needs a key. |
| `PUT /upload/<name>?exp=…&sig=…` | Where an upload link points (`POST` works too). No key; the link is good for an hour. |
