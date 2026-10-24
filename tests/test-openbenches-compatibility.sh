#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
installer="$repo_root/scripts/install-workbenches-widgets.sh"
launcher="$repo_root/bin/wave-container-shell.sh"
suite_root="$(mktemp -d)"
mock_bin="$suite_root/mock-bin"
trap 'rm -rf "$suite_root"' EXIT

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

make_checkout() {
    local root="$1"
    mkdir -p "$root/base-image/files"
    printf '# fixture launcher for %s\n' "$root" > "$root/base-image/files/claude-profile"
}

invoke_installer() {
    local mode="$1"
    local home="$2"
    local config="$3"
    local projects="$4"
    local explicit_root="$5"
    local args=(
        --waveterm-config "$config"
        --projects-root "$projects"
        --wsl-connection wsl://fixture
        --font-size 16
    )

    case "$mode" in
        auto)
            env -u WORKBENCHES_ROOT \
                HOME="$home" \
                WAVETERM_CONFIG_DIR="$config" \
                "$installer" "${args[@]}"
            ;;
        cli)
            env -u WORKBENCHES_ROOT \
                HOME="$home" \
                WAVETERM_CONFIG_DIR="$config" \
                "$installer" "${args[@]}" --workbenches-root "$explicit_root"
            ;;
        env)
            env \
                HOME="$home" \
                WORKBENCHES_ROOT="$explicit_root" \
                WAVETERM_CONFIG_DIR="$config" \
                "$installer" "${args[@]}"
            ;;
        *) fail "unknown installer test mode: $mode" ;;
    esac
}

invoke_launcher() {
    local mode="$1"
    local home="$2"
    local explicit_root="$3"
    local docker_log="$4"
    local cache_dir="$5"
    local args=(--shell sh --check py-bench)

    case "$mode" in
        auto)
            env -u WORKBENCHES_ROOT \
                HOME="$home" \
                USER=tester \
                PATH="$mock_bin:$PATH" \
                MOCK_DOCKER_LOG="$docker_log" \
                WAVE_WORKBENCHES_COMPOSE_CACHE="$cache_dir" \
                "$launcher" "${args[@]}"
            ;;
        cli)
            env -u WORKBENCHES_ROOT \
                HOME="$home" \
                USER=tester \
                PATH="$mock_bin:$PATH" \
                MOCK_DOCKER_LOG="$docker_log" \
                WAVE_WORKBENCHES_COMPOSE_CACHE="$cache_dir" \
                "$launcher" --workbenches-root "$explicit_root" "${args[@]}"
            ;;
        env)
            env \
                HOME="$home" \
                USER=tester \
                WORKBENCHES_ROOT="$explicit_root" \
                PATH="$mock_bin:$PATH" \
                MOCK_DOCKER_LOG="$docker_log" \
                WAVE_WORKBENCHES_COMPOSE_CACHE="$cache_dir" \
                "$launcher" "${args[@]}"
            ;;
        *) fail "unknown launcher test mode: $mode" ;;
    esac
}

validate_widgets() {
    local widgets="$1"
    local connections="$2"
    local expected_root="$3"
    local expected_projects="$4"

    python3 - "$widgets" "$connections" "$expected_root" "$expected_projects" <<'PY'
import json
import pathlib
import sys

widgets_path, connections_path, expected_root, expected_projects = sys.argv[1:]
raw_widgets = pathlib.Path(widgets_path).read_text(encoding="utf-8")
widgets = json.loads(raw_widgets)
connections = json.loads(pathlib.Path(connections_path).read_text(encoding="utf-8"))

for placeholder in (
    "__WORKBENCHES_ROOT__",
    "__PROJECTS_ROOT__",
    "__WSL_CONNECTION__",
    "__WAVE_WIDGET_FONT_SIZE__",
):
    assert placeholder not in raw_widgets, f"unrendered placeholder: {placeholder}"

for name in ("pyBench", "flutterBench", "cppBench", "rustBench", "cloudBench"):
    meta = widgets[name]["blockdef"]["meta"]
    assert meta["cmd:cwd"] == expected_root, (name, meta["cmd:cwd"], expected_root)
    expected_prefix = f"exec {expected_root}/scripts/wave-container-shell.sh "
    assert meta["cmd:initscript"].startswith(expected_prefix), (name, meta["cmd:initscript"])
    assert meta["connection"] == "wsl://fixture"
    assert meta["term:fontsize"] == 16

projects_meta = widgets["projects"]["blockdef"]["meta"]
assert projects_meta["file"] == expected_projects
assert projects_meta["connection"] == "wsl://fixture"
assert connections == {"wsl://fixture": {"conn:wshenabled": True}}
PY
}

run_discovery_case() {
    local name="$1"
    local layout="$2"
    local mode="$3"
    local case_root="$suite_root/$name"
    local fake_home="$case_root/home"
    local expected_root
    mkdir -p "$fake_home"

    case "$layout" in
        old-only)
            make_checkout "$fake_home/projects/workBenches"
            expected_root="$fake_home/projects/workBenches"
            ;;
        new-only)
            make_checkout "$fake_home/projects/openBenches"
            expected_root="$fake_home/projects/openBenches"
            ;;
        both-present)
            make_checkout "$fake_home/projects/openBenches"
            make_checkout "$fake_home/projects/workBenches"
            expected_root="$fake_home/projects/openBenches"
            ;;
        old-only-uppercase)
            make_checkout "$fake_home/Projects/workBenches"
            expected_root="$fake_home/Projects/workBenches"
            ;;
        new-only-uppercase)
            make_checkout "$fake_home/Projects/openBenches"
            expected_root="$fake_home/Projects/openBenches"
            ;;
        split-roots)
            make_checkout "$fake_home/projects/workBenches"
            make_checkout "$fake_home/Projects/openBenches"
            expected_root="$fake_home/Projects/openBenches"
            ;;
        *) fail "unknown checkout layout: $layout" ;;
    esac

    local explicit_root="$case_root/explicit-checkout"
    if [[ "$mode" != auto ]]; then
        make_checkout "$explicit_root"
        expected_root="$explicit_root"
    fi

    local wave_config="$case_root/wave-config"
    local widget_projects="$case_root/widget-projects"
    local output
    if ! output="$(invoke_installer "$mode" "$fake_home" "$wave_config" "$widget_projects" "$explicit_root" 2>&1)"; then
        echo "$output" >&2
        fail "$name installer invocation failed"
    fi

    validate_widgets \
        "$wave_config/widgets.json" \
        "$wave_config/connections.json" \
        "$expected_root" \
        "$widget_projects"
    [[ -x "$expected_root/scripts/wave-container-shell.sh" ]] || fail "$name did not install the launcher at the selected root"
    cmp -s "$launcher" "$expected_root/scripts/wave-container-shell.sh" || fail "$name installed a different launcher"
    bash -n "$expected_root/scripts/wave-container-shell.sh"

    local docker_log="$case_root/docker.log"
    : > "$docker_log"
    if ! output="$(invoke_launcher "$mode" "$fake_home" "$explicit_root" "$docker_log" "$case_root/compose-cache" 2>&1)"; then
        echo "$output" >&2
        fail "$name launcher invocation failed"
    fi

    local expected_copy="cp $expected_root/base-image/files/claude-profile py-bench:/usr/local/bin/claude-profile"
    grep -Fqx -- "$expected_copy" "$docker_log" || fail "$name launcher did not use the selected checkout"
}

mkdir -p "$mock_bin"
cat > "$mock_bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$MOCK_DOCKER_LOG"

if [[ "${1:-}" == "container" && "${2:-}" == "inspect" && "${3:-}" == "-f" ]]; then
    case "${4:-}" in
        *State.Running*) printf '%s\n' true ;;
    esac
fi

exit 0
MOCK
chmod +x "$mock_bin/docker"

bash -n "$installer"
bash -n "$launcher"

run_discovery_case old-only old-only auto
run_discovery_case new-only new-only auto
run_discovery_case both-present both-present auto
run_discovery_case old-only-uppercase old-only-uppercase auto
run_discovery_case new-only-uppercase new-only-uppercase auto
run_discovery_case split-roots split-roots auto
run_discovery_case explicit-root both-present cli
run_discovery_case environment-root both-present env

no_root="$suite_root/no-checkout"
mkdir -p "$no_root/home"
legacy_default="$no_root/home/projects/workBenches"
if output="$(invoke_installer auto "$no_root/home" "$no_root/wave-config" "$no_root/widget-projects" "" 2>&1)"; then
    fail "installer unexpectedly succeeded without a checkout"
fi
grep -Fq "workBenches root does not exist: $legacy_default" <<<"$output" || fail "installer did not retain the legacy default"

: > "$no_root/docker.log"
if output="$(invoke_launcher auto "$no_root/home" "" "$no_root/docker.log" "$no_root/compose-cache" 2>&1)"; then
    fail "launcher unexpectedly succeeded without a checkout"
fi
grep -Fq "workBenches root does not exist: $legacy_default" <<<"$output" || fail "launcher did not retain the legacy default"

echo "PASS: openBenches checkout discovery and generated widget fixture tests"
