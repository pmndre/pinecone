# The menu bar app

[Setup](setup.md) · [Configuration](configuration.md) · [Media tools](tools.md) · [Clients](clients.md) · [API](api.md) · [The app](app.md) · [Operations](operations.md)

Pinecone.app shows what the scheduler is doing and holds the settings that are yours to decide.

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="images/panel-dark.png">
    <img src="images/panel.png" alt="The panel" width="380">
  </picture>
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="images/settings-dark.png">
    <img src="images/settings.png" alt="Settings" width="380">
  </picture>
</p>

    menubar/build.sh                                   # needs only the Xcode Command Line Tools
    cp -R menubar/build/Pinecone.app /Applications/

Or take `Pinecone-<version>.dmg` from a release on GitHub. It needs macOS 15 or later.

## Releases

Every push to `main` is a release, as in pine (`.github/workflows/release.yml`): the tests are run, the
next version is tagged, and a GitHub release is made with the app attached. The patch number goes up,
unless a commit since the last release says `[minor]` or `[major]` in its subject; a push whose last
commit says `[skip release]` in its subject releases nothing. Work goes to `next`, the default branch, and reaches `main`
when it is to be released.

`menubar/pack.sh <version>` makes the disk image: one app for both kinds of Mac (it needs Xcode, for the
two architectures). With the signing secrets in its environment it signs the app with a Developer ID and
the hardened runtime, has Apple notarise the app and then the disk image, staples both, and checks them
as another Mac would (`spctl`). Without them it signs ad hoc, for trying on this Mac only. The workflow
reads the secrets from an environment named `release` that only `main` may use; they are pine's five
(`CSC_LINK`, `CSC_KEY_PASSWORD`, `APPLE_API_KEY`, `APPLE_API_KEY_ID`, `APPLE_API_ISSUER`), described at the top
of the workflow. Without them a release still happens, and the job that builds the app says it built none.

The icon is faded while the scheduler is off and shows a dot while something is loading or working. The
panel lists models and services with their state and memory, a memory bar split by what is loaded, what
is waiting, CPU, GPU and memory graphs, the endpoints to give to clients (with a button to copy each),
and recent activity. A model or service that is loaded and idle has a button to unload it, and a mistake
in `config.json` is shown at the top. The switch at the top starts and stops the background services
installed by `launchd/install.sh`.

Models and services are two lists, each under a line that folds it away with a click, as pine's side bar
has an agent and its conversations. A model or service that is loading, unloading or answering a request
shows a spinner, and so does the line of its list, so work is seen when the list is folded. One that did
not start shows a "!" and says why. What a name stands for (its `title` in the config) shows when the
pointer rests on it. What is folded is kept in the app's preferences on this Mac.

The panel is drawn in the design language of pine's desktop app (`desktop/DESIGN.md` in the pine
repository). pine's page is stock shadcn in its `base-nova` style; the app is SwiftUI, so each part is drawn
after its shadcn counterpart, at the same sizes and with the same variants: Card, Item, Field, Alert, Button,
Switch, Slider, ToggleGroup. The panel is one of pine's side bars, with the inset of pine's tab content, and
its ends fade where there is more to scroll to. Light and dark follow the system, and dark is pine's pmndre
theme. Settings, This app, "Appearance" keeps it light or dark whatever the system is set to. The choice is
the app's own, kept in its preferences on this Mac and not in `config.json`. The colours and sizes are in
`Theme`, and the parts follow it, in `App.swift`.

Settings hold what is the user's to decide on this Mac: the memory split and whether the scheduler sets the
GPU memory limit, whether and where other devices reach it and on which port, how long a request waits
before it goes first, access tokens, for each model and service its planned memory and how long it stays
loaded, and for the media tools their address for other devices and after how many days results are
deleted. It also lists the tools, with any that were left out and why, and has "Open at login" and "Appearance". Save sends
what changed to the scheduler, which writes it into `config.json` and applies it; reachability and port
take effect when the scheduler is started again, the media address when the media server is. What sets a model or a tool up (start commands, paths, ports, model
files, the tools themselves) is not in Settings: that is edited in the file, by you or by an AI agent.

The app keeps no list of models. Everything it shows comes from `/scheduler/status`. Pointed at a
scheduler on another Mac (Settings, This app, "Watch a scheduler on another Mac…"), it asks for an access
token and shows status only; unloading an idle model still works.

`Pinecone --snapshot out.png [--settings] [--dark]` draws the panel into a picture and quits, for checking
design changes without clicking through the app. It needs a running scheduler to have something to show;
`-serverURL http://127.0.0.1:PORT` points it at another one for this run only, without changing the app's
preferences. A picture shows the lists unfolded.
`Pinecone --icon out.png` draws the three states of the menu bar icon.
