# Install Wave Terminal

Wave Terminal setup and custom widgets for OpenSoft workBenches.

This repository documents the Wave Terminal widgets used to open workBench Docker
containers from WSL. The widgets start in WSL, then run a launcher that starts or
repairs the target container and execs into it with an interactive `zsh` shell.

## Quick Install

```bash
git clone https://github.com/opensoft/Install-Wave-Terminal.git
cd Install-Wave-Terminal

./scripts/install-workbenches-widgets.sh \
  --workbenches-root "$HOME/projects/workBenches" \
  --wsl-connection "wsl://Ubuntu-24.04"
```

The installer:

- copies `bin/wave-container-shell.sh` into `workBenches/scripts/`
- renders the widget template with your workBenches path and WSL connection
- merges the workBench widget definitions into Wave's `widgets.json`

On WSL, the installer writes to the Windows user's Wave config directory, for
example `/mnt/c/Users/<you>/.config/waveterm/widgets.json`. On native Linux, it
uses `~/.config/waveterm/widgets.json`.

Restart Wave Terminal or reload its widget list, then open one of the workBench
widgets.

## Included Widgets

| Widget | Container | workBenches path | Notes |
| --- | --- | --- | --- |
| `pyBench` | `py-bench` | `devBenches/pyBench` | Python development container |
| `flutterBench` | `flutter-bench` | `devBenches/flutterBench` | Flutter container; requires the bench to be installed |
| `C++Bench` | `cpp-bench` | `devBenches/cppBench` | C++ development container with Powerlevel10k shell config |
| `cloudBench` | `cloud-bench` | `sysBenches/cloudBench` | Cloud tooling container with home, Azure config, and Docker socket mounts |

## How It Works

Each Wave widget uses:

- `view: term`
- `controller: shell`
- `connection: wsl://Ubuntu-24.04`
- `cmd:cwd: <workBenches root>`
- `cmd:initscript: exec <workBenches root>/scripts/wave-container-shell.sh ...`

The launcher prefers the Dev Containers CLI when a bench has a
`.devcontainer/devcontainer.json`. If that path is unavailable or fails, it falls
back to Docker Compose plus a generated override file under
`~/.cache/workbenches/wave-compose/`.

The fallback override mounts shell and agent configuration from the WSL home
directory so the container shell keeps the same `zsh`, Oh My Zsh, Powerlevel10k,
Git, GitHub CLI, SSH, and agent settings.

## Security Note

These widgets intentionally mount host configuration and credentials into trusted
local workBench containers. Do not use this launcher with untrusted images or
third-party compose files without reviewing the mounts first.

See [docs/workbenches-widgets.md](docs/workbenches-widgets.md) for the widget
details and troubleshooting notes.
