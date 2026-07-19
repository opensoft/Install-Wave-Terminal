#!/usr/bin/env bash
# Install or update the workBenches Wave widgets.

set -euo pipefail

home_dir="${HOME:?HOME is required}"
repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
workbenches_root="${WORKBENCHES_ROOT:-$home_dir/projects/workBenches}"
projects_root="${PROJECTS_ROOT:-$home_dir/projects}"
wsl_connection="${WAVE_WSL_CONNECTION:-wsl://Ubuntu-24.04}"

is_wsl() {
    [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version 2>/dev/null
}

default_waveterm_config_dir() {
    if is_wsl && command -v powershell.exe >/dev/null 2>&1 && command -v wslpath >/dev/null 2>&1; then
        local windows_profile
        local wsl_profile
        windows_profile="$(powershell.exe -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' 2>/dev/null | tr -d '\r' || true)"
        if [[ -n "$windows_profile" ]]; then
            wsl_profile="$(wslpath -u "$windows_profile" 2>/dev/null || true)"
            if [[ -n "$wsl_profile" ]]; then
                printf '%s\n' "$wsl_profile/.config/waveterm"
                return
            fi
        fi
    fi

    printf '%s\n' "$home_dir/.config/waveterm"
}

waveterm_config_dir="${WAVETERM_CONFIG_DIR:-$(default_waveterm_config_dir)}"

usage() {
    cat <<'EOF'
Usage: install-workbenches-widgets.sh [options]

Options:
  --workbenches-root PATH  workBenches checkout path
  --projects-root PATH     Projects directory for the Wave files widget (default: ~/projects)
  --wsl-connection URI     Wave WSL connection URI (default: wsl://Ubuntu-24.04)
  --waveterm-config PATH   Wave config directory (default: Windows Wave config on WSL, otherwise ~/.config/waveterm)
  -h, --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --workbenches-root) workbenches_root="$2"; shift 2 ;;
        --projects-root) projects_root="$2"; shift 2 ;;
        --wsl-connection) wsl_connection="$2"; shift 2 ;;
        --waveterm-config) waveterm_config_dir="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --*) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
        *) echo "Unexpected argument: $1" >&2; usage >&2; exit 1 ;;
    esac
done

if [[ ! -d "$workbenches_root" ]]; then
    echo "workBenches root does not exist: $workbenches_root" >&2
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo "python3 is required to merge Wave config JSON." >&2
    exit 1
fi

workbenches_root="$(cd "$workbenches_root" && pwd)"
mkdir -p "$workbenches_root/scripts" "$projects_root" "$waveterm_config_dir"
projects_root="$(cd "$projects_root" && pwd)"

install -m 755 "$repo_dir/bin/wave-container-shell.sh" "$workbenches_root/scripts/wave-container-shell.sh"

template_file="$repo_dir/templates/workbenches.widgets.json"
widgets_file="$waveterm_config_dir/widgets.json"
connections_file="$waveterm_config_dir/connections.json"

python3 - "$template_file" "$widgets_file" "$connections_file" "$workbenches_root" "$projects_root" "$wsl_connection" <<'PY'
import json
import pathlib
import sys

template_path, widgets_path, connections_path, workbenches_root, projects_root, wsl_connection = sys.argv[1:]


def read_json_object(path_text):
    path = pathlib.Path(path_text)
    if path.exists() and path.stat().st_size:
        value = json.loads(path.read_text(encoding="utf-8"))
    else:
        value = {}

    if not isinstance(value, dict):
        raise SystemExit(f"{path_text} must contain a JSON object")

    return path, value

template_text = pathlib.Path(template_path).read_text(encoding="utf-8")
template_text = template_text.replace("__WORKBENCHES_ROOT__", workbenches_root)
template_text = template_text.replace("__PROJECTS_ROOT__", projects_root)
template_text = template_text.replace("__WSL_CONNECTION__", wsl_connection)
incoming = json.loads(template_text)

widgets_file, widgets = read_json_object(widgets_path)
widgets.update(incoming)
widgets_file.write_text(json.dumps(widgets, indent=2) + "\n", encoding="utf-8")

connections_file, connections = read_json_object(connections_path)
connection = connections.get(wsl_connection)
if connection is None:
    connections[wsl_connection] = {"conn:wshenabled": True}
elif isinstance(connection, dict):
    connection["conn:wshenabled"] = True
else:
    raise SystemExit(f"{connections_path} entry for {wsl_connection} must contain a JSON object")

connections_file.write_text(json.dumps(connections, indent=2) + "\n", encoding="utf-8")
PY

echo "Installed launcher: $workbenches_root/scripts/wave-container-shell.sh"
echo "Updated widgets: $widgets_file"
echo "Updated connections: $connections_file"
echo "Projects widget root: $projects_root"
echo "WSL connection: $wsl_connection"
