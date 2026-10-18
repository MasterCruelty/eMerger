#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "--security: apt without unattended-upgrades is skipped and names the package to install" {
    # A PATH of every system command except unattended-upgrade.
    mkdir -p "$HOME/sysbin"
    local f
    for f in /usr/bin/* /bin/*; do
        [ -d "$f" ] || [ "${f##*/}" = unattended-upgrade ] || ln -sf "$f" "$HOME/sysbin/${f##*/}"
    done
    stub apt 'exit 0'
    run env PATH="$STUBS:$HOME/sysbin" EMERGER_CACHE_TTL=0 $EMERGER -n -y -nl -nc -nt --security --only apt
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip apt: no security-only updates"* ]]
    [[ "$output" == *"install the unattended-upgrades package to get security-only updates with apt"* ]]
}

@test "--security: attack full upgrade on a manager without a security channel, expected skipped" {
    stub pacman 'exit 0'
    run env PATH="$STUBS:$PATH" EMERGER_CACHE_TTL=0 $EMERGER -n -y -nl -nc -nt --security --only pacman
    [ "$status" -eq 0 ]
    [[ "$output" == *"pacman"*"no security"* ]]
    [[ "$output" != *"pacman -Syu"* ]]
}

@test "--security: managers with a security channel keep it" {
    run lib "source $LIB/load.sh registry detect icon recipes; sys_has() { [[ \$1 == dnf || \$1 == zypper ]]; }
             for m in dnf zypper yum apt pacman flatpak; do pkg_has_security \$m && echo \$m; done"
    [ "$output" = "$(printf 'dnf\nzypper\nyum')" ]
}
