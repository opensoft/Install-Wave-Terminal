# workBenches Wave Widgets

This document records the Wave Terminal widget setup for OpenSoft workBenches.

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
- Icon: `smartphone`
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
- `~/.zsh_history`

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

### Dev Containers CLI Fails

The launcher tries the Dev Containers CLI first for benches with
`.devcontainer/devcontainer.json`. If that fails, it falls back to Docker Compose
with a generated override. The fallback is enough for Wave widget shells, but
the failing devcontainer command should still be fixed in the workBenches repo
when VS Code parity matters.
