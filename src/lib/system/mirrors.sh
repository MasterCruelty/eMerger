#!/usr/bin/env bash
# Mirror ranking and refresh for the managers that support it.

# Print the os-release text. Tests replace this function.
_mirrors_os_release() {
    cat /etc/os-release 2>/dev/null || true
}

# Print the running Debian release codename, or nothing on any other
# distribution (netselect-apt only knows Debian's own suites) and on testing
# or sid, which carry no VERSION_ID and share one codename.
_mirrors_debian_suite() {
    local text id version codename
    text=$(_mirrors_os_release)
    id=$(sed -n 's/^ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' <<<"$text")
    version=$(sed -n 's/^VERSION_ID="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' <<<"$text")
    codename=$(sed -n 's/^VERSION_CODENAME="\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' <<<"$text")
    [[ $id == debian && -n $version && $codename =~ ^[a-z]+$ ]] && printf '%s' "$codename"
    return 0
}

# Return 0 when root-owned file $1 holds only "deb"/"deb-src" lines with an
# http(s) URL, a suite and components, no [options] such as trusted=yes, and
# comments or blanks.
_mirrors_list_is_plain() {
    local line content
    content=$(sys_as_root cat -- "$1") || return 1
    while IFS= read -r line; do
        [[ -z $line || $line == "#"* ]] && continue
        [[ $line =~ ^deb(-src)?\ +https?://[A-Za-z0-9._~:/%+-]+\ +[A-Za-z0-9._/-]+(\ +[A-Za-z0-9._-]+)+\ *$ ]] || return 1
    done <<<"$content"
    return 0
}

# Rank mirrors with the tools present and write the result as root.
mirrors_refresh() {
    ui_title "Refresh mirrors"
    if (( DRY_RUN )); then
        ui_sub "[dry-run] would refresh mirrors"
        return 0
    fi
    local is_refreshed=0
    if sys_has reflector; then
        if sys_as_root reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist >/dev/null 2>&1; then
            ui_ok "reflector: pacman mirrorlist updated"
            is_refreshed=1
        else
            ui_warn "reflector failed"
        fi
    fi
    local suite
    if sys_has netselect-apt && suite=$(_mirrors_debian_suite) && [[ -n $suite ]]; then
        # Root owns the list from creation to install: a user-owned file could be
        # rewritten in between and plant an apt source.
        local tmp
        if ! tmp=$(sys_as_root mktemp -t emerger.XXXXXX); then
            ui_warn "netselect-apt: could not create a temp file as root"
        elif sys_as_root netselect-apt -o "$tmp" "$suite" >/dev/null 2>&1 && [[ -s $tmp ]]; then
            if ! _mirrors_list_is_plain "$tmp"; then
                ui_warn "netselect-apt: output is not a plain http(s) source list, not installed"
            elif sys_as_root install -m 0644 "$tmp" /etc/apt/sources.list.d/netselect.list; then
                ui_ok "netselect-apt: wrote /etc/apt/sources.list.d/netselect.list"
                is_refreshed=1
            else
                ui_warn "netselect-apt: could not install /etc/apt/sources.list.d/netselect.list"
            fi
        fi
        [[ -n ${tmp:-} ]] && sys_as_root rm -f "$tmp"
    fi
    if sys_has dnf && dnf config-manager --help >/dev/null 2>&1; then
        ui_muted "dnf: the fastestmirror plugin ranks mirrors when enabled"
    fi
    (( is_refreshed )) || ui_muted "No mirror tool available; install 'reflector' (arch) or 'netselect-apt' (debian)."
}
