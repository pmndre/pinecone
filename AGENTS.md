# Working on Pinecone

For an agent (or a person) who changes the code or operates a running install. Read `README.md` first, then
`docs/`: `setup.md` gets it running, `configuration.md` has every setting of the scheduler, `tools.md` the
media server's settings and the tool format, `clients.md` what a client needs, `api.md` the HTTP API,
`app.md` the menu bar app, `operations.md` what to run and where to look. This file is the map: what is where, and the rules that are not written in the code.

Pinecone is a scheduler. It brings no model and no inference server: it starts the servers a user has, when
they are asked for, and stops them when the memory is needed for something else. Nothing that belongs to one
model or one service goes into this repository.

## The repository

| Path | What |
|---|---|
| `scheduler/scheduler.py` | The whole scheduler, one file (aiohttp). |
| `scheduler/install-gpu-limit.sh` | Installs the root helper that sets the GPU memory limit. |
| `scheduler/tests/` | Tests against stand-in servers (`dummy.py`), on their own port. No models needed, except `cache_live.py` (a real llama.cpp server; `tiny_model.py` makes a model for it). |
| `media_mcp/server.py` | The media MCP server, one file. It knows no media tool: it builds them from `"tools"` in the config. |
| `media_mcp/tests/` | `tools.py` checks the tools of the example config without any service; `call.py` calls one tool of a running server. |
| `envfile.py` | Shared by both services: where the user's folder is, the first-start copy, `$NAME` variables, writing config. |
| `config.example.json`, `.env.example` | What a new user's `~/.pinecone/` starts with, including the tools that ship. |
| `menubar/` | The menu bar app: `Sources/Pinecone/App.swift` (views, and the parts they are made of), `Monitor.swift` (state, requests), `build.sh` (this Mac), `pack.sh` (a signed, notarised disk image). |
| `.github/workflows/release.yml` | Every push to `main`: tests, the next version, a GitHub release with the app attached. |
| `launchd/` | Templates and `install.sh` for running the two services at login. |
| `docs/` | The documentation, one page for each subject, and `images/` for the pictures in it. |
| `examples/` | Files for clients, such as a provider entry for pine. |
| `reel/` | A short film about Pinecone, drawn by code. Not part of the program; `reel/README.md` says how to render it. |
| `requirements.txt` | The packages of the scheduler and the media server. They share one environment, `.venv/`. |

## A user's folder

Nothing of a user's is in the repository. It is all in `~/.pinecone/` (`PINECONE_HOME` names another folder),
so the program can be replaced or moved without touching a setup.

| In `~/.pinecone/` | What |
|---|---|
| `config.json` | Models and services (`"resources"`), the media server's settings (`"media"`) and its tools (`"tools"`). The one file to edit. |
| `.env` | Paths and addresses of this Mac, used in the config as `$NAME`. |
| `internal-key.txt`, `tokens.json` | The scheduler's own key, and the access tokens (as hashes). |
| `logs/` | Output of the scheduler, the media server and every model server, one file each. |
| `files/` | What the media tools made and what was uploaded to them. Deleted after `keep_days`. |
| `cache/` | What `keep_cache` saves of a model's slots, one folder for each model. |
| `*.py`, workflow files | Tools written in Python and ComfyUI workflows that a tool in the config names. They are looked for next to the config. |
| `models/` | By convention: model files, and the server that runs them (llama.cpp). |
| `services/` | By convention: everything else a tool talks to, one folder each with its own environment (ComfyUI, mlx-audio, a speech server). |

`models/` and `services/` are a convention, not a rule. Pinecone never looks into them: the config names
every server by its start command, and the paths in it usually come from `.env` (`$MODELS`, `$COMFY`) or
are written as `$CONFIG_DIR/services/...`. Keeping them here puts a whole setup in one folder.

Never print `internal-key.txt`, `tokens.json` or `.env`, and never copy them into the repository.

## Conventions

- **One file for each service.** The scheduler is one file and the media server is one file. Keep it so.
- **A default over a required setting.** A new setting gets a value that works when it is left out.
- **Nothing model-specific in the program.** A new model is an entry under `"resources"`, a new tool an entry
  under `"tools"`. A server that a model needs but does not bring belongs in the user's `services/`, not here.
  What should ship for everyone goes into `config.example.json`, and only if it runs with the servers the
  example already names.
- **The app shows nothing it did not get from the scheduler.** A new setting goes into the scheduler first
  (config, status), then into the app.
- **A mistake shows when the config is saved, not when it is used.** `check_config` refuses a file with a
  mistake and the last good one stays in use; `check_tool` leaves a tool with a mistake out. Both say why
  (`config.error` in the status, `tool_errors` in the media server's `/health`).
- **Docs and code change together.** A setting, a route or a part of the tool format that is new or changed
  is written into its page in `docs/` in the same commit. The docs use plain words and short sentences.
- **Tests come with behaviour.** Add a check for what is new, to the tests that run without models.
- **Commits** have a subject that says what changes, as a sentence without a full stop, and a body that
  says why, what was done, and how it was tested.
- **Branches:** work goes to `next`, the default branch. A push to `main` is a release (docs/app.md,
  Releases): `[minor]` or `[major]` in a commit's subject raises that number, `[skip release]` in the last
  commit's subject releases nothing.

## Operating a running install

- **Add or change a media tool:** edit `"tools"` in `~/.pinecone/config.json` and save. `curl localhost:8090/health`
  lists the tools and names any that was left out, with the reason. Do not add tools to `server.py`.
- **Add or change a model:** edit `"resources"` in `~/.pinecone/config.json` and save. The scheduler reloads it by itself.
  Check the result with `GET /scheduler/status`: `config.error` is null when the file was accepted.
- **Do not restart the scheduler to apply config.** A restart stops every loaded model. If you must restart
  (code change), check `/scheduler/status` first and only do it when nothing is active or queued.
  With the launchd services: `launchctl kickstart -k gui/$UID/dev.pinecone.scheduler`.
- **After moving the repository,** run `launchd/install.sh` again from the new place (the services are
  installed with the folder's path) and make `.venv` again.
- **Never talk to a model server's own port.** Go through the scheduler, or its memory planning is wrong.
- **Read keys from the files, never echo them.** `$(cat ~/.pinecone/internal-key.txt)` inside a command is fine.
- **A model's real memory use** is `actual_gb` in the status while it is loaded. Set `memory_gb` a little above it.

## Running models well

What running models on a Mac taught us. None of it is about one model; the numbers are from our own tests.

**Choosing a server and a build**

- **An MLX server can be much faster than llama.cpp.** With oMLX instead of llama.cpp and GGUF, the same
  model generated 1.5 to 2.3 times as fast and read prompts 3 to 3.7 times as fast. Both models were
  mixtures of experts; a dense model may gain less. Measure before you switch.
- **Add a new server next to the old one, not in its place.** A second entry under `"resources"` can be
  measured against the first through the scheduler, and clients move over by name.
- **Prefer drafting from inside the model.** A build whose own MTP head drafts tokens (oMLX builds named
  `-mtp`) had 70 to 80 % of its drafts accepted; llama.cpp with a separate draft file had 30 to 40 %. The
  accepted share is most of the speed.
- **Drafting helps one request at a time.** oMLX drafts only while a single request runs. Three at once
  gave about as many tokens a second in total as one alone, so a higher limit on parallel requests buys
  little.
- **Check that another build has the same weights.** Fine-tunes and abliterations with the same name come
  from different makers. The name inside a GGUF can be the quantizer's. The revision hash in
  `.cache/huggingface/download/*.metadata` names the source: `GET /api/models/<repo>/revision/<hash>` on
  Hugging Face answers 200 for the right repository.
- **A repository's size** is the sum of the files in `/api/models/<repo>/tree/main?recursive=true`.
  `usedStorage` counts its whole history.
- **Downloads:** `hf download` was nearly three times as fast with `HF_XET_HIGH_PERFORMANCE=1` and
  `--max-workers 16`. Stopped and started again, it goes on where it was.

**An oMLX entry**

- **One entry, one model, one home.** Each entry runs its own `omlx serve` with its own `--base-path`. The
  `model_settings.json` there pins the model, turns MTP on and holds its sampling. Two entries that share a
  home pin, and load, each other's models.
- **`--model-dir` can be one folder for all MLX models**, but each model's folder must have its entry's
  name: the scheduler passes `"model"` through unchanged.
- **Also pass** `--no-hf-cache`, `--memory-guard-gb` equal to `memory_gb`, and
  `--paged-ssd-cache-dir $CONFIG_DIR/cache/<name>` with `--paged-ssd-cache-max-size`. That is oMLX's own store
  of what was read; it does what `keep_cache` does for llama.cpp.
- **`/health` answers 503 until the pinned model is loaded**, and the scheduler waits for that.
- **Memory for macOS:** oMLX warns when the GPU limit leaves macOS less than about 12.8 GB, because a large
  load can then get the process killed. A `system_reserve_gb` of 8 is below that; 12 or 13 is safer.

**Settings that differ between servers**

- **Thinking is switched differently.** Some chat templates take a template argument
  (`chat_template_kwargs`, for example `reasoning_effort`), others the OpenAI field, and a server may pass
  on only one of them. Ask a new server the same question at each level and compare `reasoning_tokens` in
  the usage. Some templates think at their maximum when nothing is passed.
- **Sampling:** llama.cpp started without sampling flags uses its own defaults, not the model's. oMLX takes
  `model_settings.json` and the model's `generation_config.json`. Put the model's recommended values into
  the server's settings, so every client gets them.
- **Pictures** worked on every vision model we tried. **Video** depends on the server and the model type:
  oMLX refused it for a model that understands video. Test before a tool relies on it.
- **Tool calls:** send one request with a `tools` list and check that `finish_reason` is `tool_calls`.

**Measuring**

- **Through the scheduler**, never the server's port. Start every prompt with a random line, so no cache
  helps, except in a test that sends a long prompt twice on purpose. Take the middle of three runs.
- **From the stream:** time to the first token; prompt tokens over that time for reading; tokens after the
  first over the time after it for generating. Add a run of three requests at once.
- **Stop the clients first.** Their requests make the scheduler swap models in the middle of a run.
- **Real use is slower** than a clean run: longer contexts, several requests. llama.cpp's log has the real
  numbers (`eval time ... tokens per second`, `draft acceptance`); oMLX logs `MTP[...] accept=`.
- **After a switch,** clients still name the old entry: their model list and each agent's model must
  change too. A running client may keep the old model until it is told (pine: `pine agent update <id> --model`).

## How the scheduler works

- `load_config` reads the file, checks it (`check_config`), fills in defaults and variables.
- `Res` is one resource: `off`, `starting`, `ready` or `stopping`. `Scheduler.step()` is the only place
  that decides: it hands waiting requests to ready resources and plans one load at a time
  (`evictions` says what must stop first). It runs after every event and once a second.
- A request holds its resource "active" until it ends; a lease does the same for services.
- `reload` applies a new config without interrupting anything: policy settings at once, start settings
  (`LAUNCH_KEYS`) at the resource's next load, removed resources once idle (`settle`).
- Callers are `admin` (the scheduler's own key) or a token id (`caller`). Settings and tokens need admin.

## Changing the code

- Run the scheduler's tests after any scheduler change (see `docs/operations.md`, Tests).
- After changing the media server or the tools in `config.example.json`, run `media_mcp/tests/tools.py`. It needs no services.
  To try a tool for real: `media_mcp/tests/call.py <tool> '<json arguments>'` (it loads the service).
- The app builds with the Command Line Tools only, so SwiftUI macros that need Xcode (`@State`, `#Preview`)
  are not available. View state lives in `Monitor` as `@Published` properties.
- The panel follows the design of pine's desktop app: read pine's `desktop/DESIGN.md` before changing a view.
  pine's page is stock shadcn (`base-nova`); here each part (`Card`, `Item`, `Alert`, `Pine` buttons,
  `PineSwitch`, `PineSlider`, `ToggleGroup`, `Input`, `SideGroup`) is drawn after its shadcn counterpart, at its
  sizes and with its variants. A view is made of these parts; a colour or size comes from `Theme`, never a
  value of its own.
- The app needs macOS 15 (the scroll fade reads how far the panel is scrolled).
- Check design changes with `Pinecone --snapshot out.png [--settings] [--dark]`; it renders the real panel.
