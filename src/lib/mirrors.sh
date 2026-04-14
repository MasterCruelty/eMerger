#!/usr/bin/env bash
# Rank / refresh package mirrors where supported.

mirrors_refresh() {
    ui_title "Refresh mirrors"
    if (( DRY_RUN )); then
        ui_sub "[dry-run] would refresh mirrors"
        return 0
    fi
    local did=0
    if sys_has reflector; then
        if sudo reflector --latest 20 --sort rate --protocol https --save /etc/pacman.d/mirrorlist >/dev/null 2>&1; then
            ui_ok "reflector: pacman mirrorlist updated"
            did=1
        else
            ui_warn "reflector failed"
        fi
    fi
    if sys_has netselect-apt; then
        local tmp; tmp=$(mktemp -t emerger.XXXXXX)
        trap 'rm -f "$tmp"' RETURN
        if sudo netselect-apt -o "$tmp" >/dev/null 2>&1 && [[ -s $tmp ]]; then
            sudo install -m 0644 "$tmp" /etc/apt/sources.list.d/netselect.list
            ui_ok "netselect-apt: wrote /etc/apt/sources.list.d/netselect.list"
            did=1
        fi
        rm -f "$tmp"
    fi
    if sys_has dnf && dnf config-manager --help >/dev/null 2>&1; then
        ui_muted "dnf: fastestmirror plugin handles this automatically when enabled"
    fi
    (( did )) || ui_muted "No mirror tool available; install 'reflector' (arch) or 'netselect-apt' (debian)."
}
