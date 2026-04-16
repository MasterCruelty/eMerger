#!/usr/bin/env bash
# Self-update (git pull) and auto-update scheduling (systemd user timer or cron).

self_update() {
    local root="$1"
    ui_title "Self-update"
    if [[ ! -d "$root/.git" ]]; then
        ui_err "Not a git checkout. Re-clone: git clone https://github.com/MasterCruelty/eMerger"
        return 1
    fi
    if ! sys_has git; then
        ui_err "git not installed"
        return 1
    fi
    local branch before after
    branch=$(git -C "$root" rev-parse --abbrev-ref HEAD)
    ui_info "Branch: $branch"
    if (( DRY_RUN )); then
        ui_sub "[dry-run] git -C $root pull --ff-only"
        return 0
    fi
    before=$(git -C "$root" rev-parse HEAD)
    if ! git -C "$root" fetch --quiet; then
        ui_err "git fetch failed"
        return 1
    fi
    if ! git -C "$root" pull --ff-only --quiet; then
        ui_err "git pull failed (non fast-forward?)"
        return 1
    fi
    after=$(git -C "$root" rev-parse HEAD)
    if [[ $before == "$after" ]]; then
        ui_ok "Already up to date."
    else
        ui_ok "Updated ${before:0:7}..${after:0:7}"
        git -C "$root" log --oneline "$before..$after" | sed "s/^/    $(ui_glyph dot) /"
    fi
}

setup_cron() {
    local root="$1"
    ui_title "Enable auto-update"
    if sys_has systemctl && [[ -d /run/systemd/system ]] || sys_has systemctl && systemctl --user show-environment >/dev/null 2>&1; then
        local unit_dir="$HOME/.config/systemd/user"
        mkdir -p "$unit_dir"
        cat >"$unit_dir/emerger.service" <<EOF
[Unit]
Description=eMerger automatic update

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash "$root/src/emerger.sh" -y -q -nl -ni
EOF
        cat >"$unit_dir/emerger.timer" <<EOF
[Unit]
Description=Run eMerger weekly

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
        systemctl --user daemon-reload
        systemctl --user enable --now emerger.timer
        ui_ok "systemd user timer enabled (weekly)"
        ui_muted "manage with: systemctl --user status emerger.timer"
    elif sys_has crontab; then
        local cronline="0 10 * * 0 bash \"$root/src/emerger.sh\" -y -q -nl -ni"
        ( crontab -l 2>/dev/null | grep -v "emerger.sh" || true; echo "$cronline" ) | crontab -
        ui_ok "Weekly cronjob installed (Sunday 10:00)"
    else
        ui_err "Neither systemd --user nor crontab available."
        return 1
    fi
}
