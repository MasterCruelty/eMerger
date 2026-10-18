#!/usr/bin/env bash
# System detection helpers.

# Return 0 if command $1 is on PATH.
sys_has() { command -v "$1" >/dev/null 2>&1; }
# Return 0 on macOS.
sys_is_macos() { [[ $(uname -s) == Darwin ]]; }
# Print Homebrew's prefix, returning 1 when brew is missing or fails.
sys_brew_prefix() { command -v brew >/dev/null 2>&1 && brew --prefix 2>/dev/null; }

# Print the distribution name from /etc/os-release (PRETTY_NAME, else NAME),
# else the kernel name and release. Sourcing the file leaves its variables set.
sys_read_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-unknown}}"
    else
        uname -sr
    fi
}

# Print the start-up file of the user's SHELL: ~/.bashrc, $ZDOTDIR/.zshrc,
# fish's config.fish, else ~/.<shell>rc.
sys_shell_rc() {
    local shell
    shell=$(basename "${SHELL:-bash}")
    case "$shell" in
        bash) echo "$HOME/.bashrc" ;;
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "$HOME/.${shell}rc" ;;
    esac
}

# Print the free space of the file system holding path $2 in df block size
# $1 (k for KiB, m for MiB), empty when df fails.
sys_free_space() {
    { df -P"$1" "$2" 2>/dev/null || true; } | awk 'NR==2{print $4}'
}

# Return 0 when the effective uid is 0.
sys_is_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }

# Print the privilege prefix for a root-only command: nothing as root (a
# container or CI image may have no sudo), `sudo` otherwise.
sys_sudo_prefix() {
    sys_is_root || printf 'sudo'
    return 0
}

# Run command $@ as root: directly as root, through sudo otherwise. The lock
# fd stays out of it, so a daemon the command leaves behind cannot hold the lock.
sys_as_root() {
    local prefix
    prefix=$(sys_sudo_prefix)
    ${prefix:+"$prefix"} "$@" 9>&-
}

# Return 0 while the calling subshell's parent is still process $1. An
# orphan is re-parented, so a PID reused after the parent died does not count.
# Without ps, fall back to `kill -0`.
sys_is_parent_alive() {
    # Read BASHPID here: inside $(...) it names the substitution's subshell.
    local parent self="${BASHPID:-$$}"
    parent=$(ps -o ppid= -p "$self" 2>/dev/null) || { kill -0 "$1" 2>/dev/null; return; }
    parent=${parent//[!0-9]/}
    [[ -z $parent ]] && { kill -0 "$1" 2>/dev/null; return; }
    [[ $parent == "$1" ]]
}
