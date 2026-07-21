# workBenches Wave Widgets

This document records the Wave Terminal widget setup for OpenSoft workBenches.

The installer also overrides Wave's built-in terminal widget so the default
terminal button opens the configured WSL connection instead of PowerShell on
Windows.

It also adds a `projects` files widget rooted at the configured projects
directory. The default root is `$HOME/projects`.

All generated widgets use a default font size of `16`. Terminal widgets set
`term:fontsize`; the `projects` files widget sets `editor:fontsize`,
`markdown:fontsize`, and `markdown:fixedfontsize`.

## workBenches Setup Integration

The root `workBenches/setup.sh` invokes this installer before Docker image
builds. That makes the Wave `terminal`, `projects`, and container widgets part
of the shared workBenches setup instead of a one-off manual workstation step.

## Widget Contract

Wave launches each widget in WSL, then the widget init script replaces the WSL
shell with `wave-container-shell.sh`. The launcher makes sure the Docker
container exists, starts it if needed, and runs an interactive login `zsh` shell
inside the container.

The widget title is set in two ways:

- terminal OSC title escape
- `wsh setmeta -b this frame:title=... frame:text=...` when `wsh` is available

That keeps the Wave block title aligned with the widget label.

## Widgets

### Default Terminal

- Widget key: `defwidget@terminal`
- Label: `terminal`
- Icon: `square-terminal`
- Connection: `wsl://Ubuntu-24.04` by default
- Font size: `16`

Wave uses the `defwidget@terminal` key to override its built-in terminal widget.
The installer renders that key with the selected `--wsl-connection`, so the
standard terminal widget opens Ubuntu 24.04 WSL instead of the Windows default
shell.

### projects

- Widget key: `projects`
- Label: `projects`
- Icon: `folder`
- View: `preview`
- Connection: `wsl://Ubuntu-24.04` by default
- File root: `$HOME/projects` by default
- Font size: `16`

The installer renders the `projects` widget with the selected
`--wsl-connection` and `--projects-root`. On Brett's workstation this resolves
to `wsl://Ubuntu-24.04` and `/home/brett/projects`, so the files widget browses
the WSL projects directory instead of the Windows filesystem.

### pyBench

- Widget key: `pyBench`
- Label: `pyBench`
- Icon: `brands@python`
- Container: `py-bench`
- Bench directory: `devBenches/pyBench`
- Compose file: `devBenches/pyBench/.devcontainer/docker-compose.yml`

### flutterBench

- Widget key: `flutterBench`
- Label: `flutterBench`
- Icon: `brands@flutter`
- Container: `flutter-bench`
- Bench directory: `devBenches/flutterBench`
- Compose file: `devBenches/flutterBench/.devcontainer/docker-compose.yml`

The launcher prints a clear message if the Flutter bench has not been installed
yet.

### C++Bench

- Widget key: `cppBench`
- Label: `C++Bench`
- Icon: `file-code`
- Container: `cpp-bench`
- Bench directory: `devBenches/cppBench`
- Compose file: `devBenches/cppBench/.devcontainer/docker-compose.yml`

The C++ container needs the shell config mounts for Powerlevel10k:

- `~/.zshrc`
- `~/.oh-my-zsh`
- `~/.p10k.zsh`
- `~/.workbenches-history/` with `HISTFILE=~/.workbenches-history/.zsh_history`

The launcher checks for the required mounts and recreates the container if an
older compose-only container is missing them.

### cloudBench

- Widget key: `cloudBench`
- Label: `cloudBench`
- Icon: `cloud`
- Container: `cloud-bench`
- Bench directory: `sysBenches/cloudBench`
- Compose file: `sysBenches/cloudBench/.devcontainer/docker-compose.yml`

`cloudBench` uses its own devcontainer compose file, which mounts:

- WSL home at `/home/<user>`
- Azure config at `/home/<user>/.azure`
- Docker socket at `/var/run/docker.sock`
- cloudBench workspace at `/workspace`

The launcher treats those parent mounts as satisfying the shell/home mount
requirements.

## Troubleshooting

### Default Terminal Still Opens PowerShell

Confirm the built-in terminal override exists in Wave's Windows-side config:

```bash
jq '."defwidget@terminal".blockdef.meta.connection' /mnt/c/Users/<you>/.config/waveterm/widgets.json
```

It should print `wsl://Ubuntu-24.04` unless a different connection was passed to
`--wsl-connection`. Restart Wave Terminal or reload the widget list after
installing.

### Widget Opens WSL Instead of The Container

That usually means the widget ran without replacing the WSL shell. Confirm the
widget init script is rendered with the right workBenches path:

```bash
jq '.pyBench.blockdef.meta["cmd:initscript"]' ~/.config/waveterm/widgets.json
```

Then test the launcher directly:

```bash
~/projects/workBenches/scripts/wave-container-shell.sh --check pyBench
```

### Powerlevel10k Setup Appears

The container is missing the shell config mounts. Run:

```bash
docker inspect cpp-bench --format '{{range .Mounts}}{{println .Destination}}{{end}}'
```

You should see either the specific shell config mounts or a parent home mount.
If not, run:

```bash
~/projects/workBenches/scripts/wave-container-shell.sh --check C++Bench
```

The launcher will recreate a container that is missing required mounts.

### Dev Containers CLI Fails Or Hangs

For first creation, the launcher tries the Dev Containers CLI for benches with
`.devcontainer/devcontainer.json`, but only for a short timeout. If it fails or
hangs, the launcher removes any half-created container and falls back to Docker
Compose with a generated Wave override.

For existing containers that are missing required mounts, the launcher skips the
Dev Containers CLI and recreates the container directly with the Wave compose
override. The fallback is enough for Wave widget shells, but a broken
devcontainer command should still be fixed in the workBenches repo when VS Code
parity matters.
