#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

# Stub reflector, netselect-apt, install and a logging sudo for mirrors_refresh.
stub_mirror_tools() {
    stub reflector 'echo "reflector $*" >>"$HOME/calls"'
    stub netselect-apt 'echo "netselect-apt $*" >>"$HOME/calls"; [ "$1" = -o ] && echo "deb http://mirror.example/debian $3 main" >"$2"; exit 0'
    stub install 'echo "install $*" >>"$HOME/calls"'
    stub sudo 'echo "sudo $*" >>"$HOME/calls"; exec "$@"'
}

# Shell code that sources the mirror lib and answers as Debian 13.
MIRRORS_DEBIAN='source "$LIB/load.sh" mirrors
    _mirrors_os_release() { printf "ID=debian\nVERSION_ID=13\nVERSION_CODENAME=trixie\n"; }'

# Stub sudo, netselect-apt and install for mirrors_refresh; $1 is install's exit code.
stub_netselect() {
    cat >"$STUBS/sudo" <<'EOS'
#!/bin/bash
echo "sudo $*" >>"$HOME/sudo.log"
"$@"
EOS
    cat >"$STUBS/netselect-apt" <<'EOS'
#!/bin/sh
echo "netselect-apt $*" >>"$HOME/sudo.log"
[ "$1" = -o ] && echo "deb http://mirror.example/debian $3 main" >"$2"
EOS
    printf '#!/bin/sh\nexit %s\n' "$1" >"$STUBS/install"
    chmod +x "$STUBS/sudo" "$STUBS/netselect-apt" "$STUBS/install"
}

# Run mirrors_refresh with the stubs and the os-release file given.
run_mirrors() {
    bash -c 'set -Eeuo pipefail; PATH="$STUBS:$PATH"; source "$LIB/load.sh" ui sys mirrors
             osr=$1; _mirrors_os_release() { cat "$osr"; }; sys_is_root() { return 1; }
             DRY_RUN=0; mirrors_refresh; echo done' _ "$1"
}

@test "mirrors: as root, reflector and netselect-apt run without sudo" {
    stub_mirror_tools
    rm "$STUBS/sudo"
    run sys_lib "$MIRRORS_DEBIAN"'; sys_is_root() { return 0; }; mirrors_refresh; echo done'
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = done ]
    [[ "$output" == *"reflector: pacman mirrorlist updated"* ]]
    [[ "$output" == *"netselect-apt: wrote"* ]]
    grep -q '^install -m 0644 ' "$HOME/calls"
}

@test "mirrors: as a user, every privileged step goes through sudo" {
    stub_mirror_tools
    run sys_lib "$MIRRORS_DEBIAN"'; sys_is_root() { return 1; }; mirrors_refresh; echo done'
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = done ]
    for c in reflector mktemp netselect-apt install rm; do grep -q "^sudo $c " "$HOME/calls"; done
}

@test "mirrors: a failing sudo mktemp warns and the run goes on" {
    stub_mirror_tools
    stub sudo 'echo "sudo $*" >>"$HOME/calls"; [ "$1" = mktemp ] && exit 1; exec "$@"'
    run sys_lib "$MIRRORS_DEBIAN"'; sys_is_root() { return 1; }; mirrors_refresh; echo done'
    [ "$status" -eq 0 ]
    [ "${lines[-1]}" = done ]
    [[ "$output" == *"netselect-apt: could not create a temp file as root"* ]]
    ! grep -q '^netselect-apt' "$HOME/calls" || false
}

@test "mirrors: the netselect-apt list is created by root, never by the user" {
    cat >"$STUBS/sudo" <<'EOS'
#!/bin/bash
echo "sudo $*" >>"$HOME/sudo.log"
if [[ $1 == mktemp ]]; then f=$("$@"); echo "$f" >"$HOME/rootfile"; echo "$f"; exit 0; fi
"$@"
EOS
    cat >"$STUBS/netselect-apt" <<'EOS'
#!/bin/sh
[ "$1" = -o ] && echo "deb http://mirror.example/debian stable main" >"$2"
EOS
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/install"
    chmod +x "$STUBS/sudo" "$STUBS/netselect-apt" "$STUBS/install"
    printf 'ID=debian\nVERSION_ID="13"\nVERSION_CODENAME=trixie\n' >"$HOME/os-release"
    run bash -c 'PATH="$STUBS:$PATH"; source "$LIB/load.sh" ui sys mirrors; _mirrors_os_release() { cat "$HOME/os-release"; }; sys_is_root() { return 1; }; DRY_RUN=0; mirrors_refresh'
    [ "$status" -eq 0 ]
    [ -s "$HOME/rootfile" ]
    grep -q "^sudo install -m 0644 $(cat "$HOME/rootfile") /etc/apt/sources.list.d/netselect.list$" "$HOME/sudo.log"
}

@test "mirrors: netselect-apt asks for the running Debian suite" {
    stub_netselect 0
    printf 'ID=debian\nVERSION_ID="13"\nVERSION_CODENAME=trixie\n' >"$HOME/os-release"
    run run_mirrors "$HOME/os-release"
    [ "$status" -eq 0 ]
    grep -q '^netselect-apt -o .* trixie$' "$HOME/sudo.log"
}

@test "mirrors: netselect-apt is skipped on a Debian derivative" {
    stub_netselect 0
    printf 'ID=ubuntu\nID_LIKE=debian\nVERSION_CODENAME=noble\n' >"$HOME/os-release"
    run run_mirrors "$HOME/os-release"
    [ "$status" -eq 0 ]
    ! grep -q '^netselect-apt' "$HOME/sudo.log"
}

@test "mirrors: a failing install warns, removes the temp file and the run goes on" {
    stub_netselect 1
    printf 'ID=debian\nVERSION_ID="13"\nVERSION_CODENAME=trixie\n' >"$HOME/os-release"
    run run_mirrors "$HOME/os-release"
    [ "$status" -eq 0 ]
    [[ "$output" == *"could not install"* ]]
    [[ "${lines[-1]}" == done ]]
    tmp=$(grep -o 'netselect-apt -o [^ ]*' "$HOME/sudo.log" | head -1 | awk '{print $3}')
    [ ! -e "$tmp" ]
}

@test "mirrors: netselect-apt is skipped on testing and sid" {
    stub_netselect 0
    printf 'ID=debian\nVERSION_CODENAME=forky\n' >"$HOME/os-release"
    run run_mirrors "$HOME/os-release"
    [ "$status" -eq 0 ]
    ! grep -q '^netselect-apt' "$HOME/sudo.log" 2>/dev/null || false
}

@test "mirrors: attack netselect-apt output with source options, expected not installed" {
    local bad
    for bad in 'deb [trusted=yes] http://mirror.example/debian trixie main' \
               'deb http://mirror.example/debian trixie main; touch /x' \
               'deb file:///tmp/x trixie main'; do
        stub reflector 'exit 1'
        stub netselect-apt "[ \"\$1\" = -o ] && printf '%s\n' '$bad' >\"\$2\"; exit 0"
        stub install 'echo "install $*" >>"$HOME/calls"'
        stub sudo 'exec "$@"'
        printf 'ID=debian\nVERSION_ID="13"\nVERSION_CODENAME=trixie\n' >"$HOME/os-release"
        run bash -c 'PATH="$STUBS:$PATH"; source "$LIB/load.sh" ui sys mirrors; _mirrors_os_release() { cat "$HOME/os-release"; }; sys_is_root() { return 1; }; DRY_RUN=0; mirrors_refresh'
        [ ! -e "$HOME/calls" ]
        [[ "$output" == *"not installed"* ]]
    done
}
