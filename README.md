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
  --projects-root "$HOME/projects" \
  --wsl-connection "wsl://Ubuntu-24.04"
```

The installer:

- copies `bin/wave-container-shell.sh` into `workBenches/scripts/`
- renders the widget template with your workBenches path and WSL connection
- merges the workBench widget definitions into Wave's `widgets.json`
- overrides Wave's built-in `terminal` widget so it opens the WSL connection
  instead of the Windows default shell
- adds a `projects` files widget rooted at the selected projects directory
- ensures the WSL connection exists in Wave's `connections.json` with WSH
  enabled

On WSL, the installer writes to the Windows user's Wave config directory, for
example `/mnt/c/Users/<you>/.config/waveterm/widgets.json`. On native Linux, it
uses `~/.config/waveterm/widgets.json`.

Restart Wave Terminal or reload its widget list, then open one of the workBench
widgets.

## workBenches Setup Integration

The root `workBenches/setup.sh` runs this installer as a best-effort host setup
step. That keeps the Wave `terminal`, `projects`, and container widgets
available for every workBenches setup without requiring each bench repo to carry
its own Wave configuration.

## Included Widgets

| Widget | Container | workBenches path | Notes |
| --- | --- | --- | --- |
| `terminal` | n/a | n/a | Built-in Wave terminal override; opens `wsl://Ubuntu-24.04` by default |
| `projects` | n/a | `$HOME/projects` | Files widget for the WSL projects directory |
| `pyBench` | `py-bench` | `devBenches/pyBench` | Python development container |
| `flutterBench` | `flutter-bench` | `devBenches/flutterBench` | Flutter container; requires the bench to be installed |
| `C++Bench` | `cpp-bench` | `devBenches/cppBench` | C++ development container with Powerlevel10k shell config |
| `cloudBench` | `cloud-bench` | `sysBenches/cloudBench` | Cloud tooling container with home, Azure config, and Docker socket mounts |

## How It Works

Each Wave widget uses:

- `view: term`
- `controller: shell`
- `connection: wsl://Ubuntu-24.04`

The default Wave terminal widget is overridden with the `defwidget@terminal`
key in `widgets.json`. That makes the standard terminal button open the
configured WSL distro instead of PowerShell on Windows.

The `projects` widget uses `view: preview`, the configured WSL connection, and
`file: <projects root>`. By default, the projects root is `$HOME/projects`; pass
`--projects-root` to render a different directory.

The workBench container widgets also use:

- `cmd:cwd: <workBenches root>`
- `cmd:initscript: exec <workBenches root>/scripts/wave-container-shell.sh ...`

For first creation, the launcher tries the Dev Containers CLI when a bench has a
`.devcontainer/devcontainer.json`, with a short timeout so Wave is not left
waiting behind a stuck `devcontainer up`. If that path is unavailable, fails, or
times out, it falls back to Docker Compose plus a generated override file under
`~/.cache/workbenches/wave-compose/`.

When an existing container is missing Wave-required mounts, the launcher
recreates it directly with the Wave Docker Compose override. This avoids a known
Dev Containers CLI hang where the container starts but the CLI never returns, so
Wave never reaches the final interactive shell.

The fallback override mounts shell and agent configuration from the WSL home
directory so the container shell keeps the same `zsh`, Oh My Zsh, Powerlevel10k,
Git, GitHub CLI, SSH, and agent settings.

## Security Note

These widgets intentionally mount host configuration and credentials into trusted
local workBench containers. Do not use this launcher with untrusted images or
third-party compose files without reviewing the mounts first.

See [docs/workbenches-widgets.md](docs/workbenches-widgets.md) for the widget
details and troubleshooting notes.
