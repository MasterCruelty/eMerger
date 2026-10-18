# Shared fixture of the bash test files: `load test_helper` from a file's top.

# Point HOME at a fresh temp directory, the old value kept in HOME_BAK, and
# export REPO_DIR, LIB, EMERGER (the entry point command), NO_COLOR and an
# empty stub directory STUBS.
setup_home() {
    export REPO_DIR="${BATS_TEST_DIRNAME}/.."
    export LIB="$REPO_DIR/src/lib"
    export EMERGER="bash $REPO_DIR/src/emerger.sh"
    export HOME_BAK="$HOME"
    export HOME="$(mktemp -d)"
    export NO_COLOR=1
    export STUBS="$HOME/stubs"
    mkdir -p "$STUBS"
}

# Export the XDG cache, config, state and runtime directories under HOME and
# create them, with an empty eMerger config directory.
setup_xdg() {
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export XDG_RUNTIME_DIR="$HOME/run"
    mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
    mkdir -p "$XDG_CONFIG_HOME/emerger"
}

# Remove the temp HOME and restore the one setup_home saved.
teardown_home() {
    rm -rf "$HOME"
    export HOME="$HOME_BAK"
}

# Write executable stub $1 into $STUBS, running shell code $2.
stub() {
    printf '#!/bin/sh\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

# Set up the full fixture of the feature files: setup_home and setup_xdg, EMERGER_STATE,
# the detection cache directory and an empty TMPDIR under HOME, no display or
# QUIET_HOURS, stubs first on PATH, and ibus (logging to $HOME/ibus.log) and
# notify-send stubbed so a real run never reaches the host's.
setup_env() {
    setup_home
    setup_xdg
    export EMERGER_STATE="$XDG_STATE_HOME/emerger"
    export TMPDIR="$HOME/tmp"
    unset DISPLAY WAYLAND_DISPLAY QUIET_HOURS
    mkdir -p "$TMPDIR" "$XDG_CACHE_HOME/emerger"
    stub ibus 'echo "ibus $*" >>"$HOME/ibus.log"'
    stub notify-send 'exit 0'
    export PATH="$STUBS:$PATH"
}

# Stop every background helper whose PID a test left in $HOME/*.pid, then
# teardown_home.
teardown_env() {
    local p
    for p in "$HOME"/*.pid; do
        [[ -f $p ]] && kill "$(cat "$p")" 2>/dev/null
    done
    teardown_home
}

# Create $MINBIN holding links to the basic host tools only, so no host
# package manager answers a probe made through sys_lib.
setup_minbin() {
    export MINBIN="$HOME/minbin"
    mkdir -p "$MINBIN"
    local t p
    for t in bash sh awk cat cut date df du find grep head mkdir mktemp numfmt \
             paste rm sed sleep sort stat tail timeout touch tr uname wc id comm join env mv; do
        p=$(command -v "$t") && ln -s "$p" "$MINBIN/$t"
    done
}

# Run snippet $1 in a fresh bash with the run's libs sourced and the state,
# log and config paths under HOME.
lib() {
    bash -c 'set -uo pipefail; printf -v IFS "\n\t"
        EMERGER_STATE=$HOME/.local/state/emerger; EMERGER_LOG=$EMERGER_STATE/log
        EMERGER_CONFIG=$HOME/.config/emerger
        mkdir -p "$EMERGER_STATE"
        source "$LIB/load.sh" ui knobs log sys progress estimate run args ignore registry detect icon \
               recipes clean rpi rpi_eeprom trust hooks plugins selfupdate autoupdate history lock \
               resume preflight reboot diff summary
        '"$1"
}

# Run snippet $1 under the entry point's shell options with the libs sourced,
# PATH limited to the stubs and $MINBIN (see setup_minbin).
sys_lib() {
    PATH="$STUBS:$MINBIN" "$MINBIN/bash" -c 'set -Eeuo pipefail; printf -v IFS "\n\t"
        EMERGER_STATE=$HOME/.local/state/emerger; EMERGER_LOG=$EMERGER_STATE/log
        EMERGER_CACHE=$HOME/.cache/emerger; EMERGER_CONFIG=$HOME/.config/emerger
        mkdir -p "$EMERGER_STATE" "$EMERGER_CACHE"
        DRY_RUN=0; ARG_YES=0; QUIET_LEVEL=0; SUMMARY_FREED_KB=0
        source "$LIB/load.sh" ui log sys progress estimate run ignore registry detect icon recipes clean rpi rpi_eeprom preflight reboot \
                 snapshot diff changelog doctor notify
        '"$1"
}

# Write plugin $1 into the user's managers.d: its run appends its name to
# $HOME/ran, then runs shell code $2. Extra function definitions go in $3.
plugin() {
    mkdir -p "$XDG_CONFIG_HOME/emerger/managers.d"
    cat >"$XDG_CONFIG_HOME/emerger/managers.d/$1.sh" <<EOF
PM_PLUGIN_SLUG=$1
pm_$1_detect() { return 0; }
pm_$1_run() {
    echo $1 >>"\$HOME/ran"
    $2
}
$3
EOF
}
