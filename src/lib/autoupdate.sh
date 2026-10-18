#!/usr/bin/env bash
# Auto-update scheduling: a weekly systemd user timer or a cron line.

# Return 0 if install path $1 can be written inside the generated alias,
# cron line and systemd unit as a double-quoted string. Characters that
# quoting, cron or systemd would interpret are refused with a message.
install_path_check() {
    local root="$1" bad=$'\'"$`%\\\n'
    if [[ $root == *["$bad"]* ]]; then
        ui_err "The install path contains a character eMerger cannot quote safely: $root"
        ui_info "Move the checkout to a path without ' \" \$ \` % \\ or a newline and run this again."
        return 1
    fi
    return 0
}

# Print the user's crontab without the lines eMerger's own cron entry
# wrote ("... bash "<path>/src/emerger.sh" -y -q -nl -ni"). Return 0 when
# there is no crontab yet, 1 (message on stderr) when it cannot be read, so a
# read failure never ends as a crontab holding the eMerger line alone.
autoupdate_crontab_others() {
    local current rc=0
    current=$(LC_ALL=C crontab -l 2>&1) || rc=$?
    if (( rc != 0 )); then
        grep -q -i -E 'no crontab|no such file' <<<"$current" && return 0
        ui_err "Cannot read the current crontab, leaving it unchanged: $current"
        return 1
    fi
    printf '%s\n' "$current" | { grep -v -E '^0 10 \* \* 0 bash ".*/src/emerger\.sh" -y -q -nl -ni$' || true; }
}

# Install a weekly run of "$1/src/emerger.sh": a systemd user timer when the
# user manager is reachable, else a crontab line. Honours DRY_RUN.
autoupdate_install() {
    local root="$1"
    ui_title "Enable auto-update"
    install_path_check "$root" || return 1
    if sys_has systemctl && [[ -d /run/systemd/system ]] || sys_has systemctl && systemctl --user show-environment >/dev/null 2>&1; then
        local unit_dir="$HOME/.config/systemd/user"
        if (( DRY_RUN )); then
            ui_sub "[dry-run] write $unit_dir/emerger.service and emerger.timer"
            ui_sub "[dry-run] systemctl --user enable --now emerger.timer"
            return 0
        fi
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
OnCalendar=Sun *-*-* 10:00:00
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF
        if ! systemctl --user daemon-reload || ! systemctl --user enable --now emerger.timer; then
            rm -f "$unit_dir/emerger.service" "$unit_dir/emerger.timer"
            ui_err "systemd refused the user timer; nothing was installed."
            ui_info "Without a login session (ssh, servers) run 'loginctl enable-linger $USER' first, then 'up -au' again."
            return 1
        fi
        ui_ok "systemd user timer enabled (Sunday 10:00)"
        ui_muted "manage with: systemctl --user status emerger.timer"
    elif sys_has crontab; then
        local cronline="0 10 * * 0 bash \"$root/src/emerger.sh\" -y -q -nl -ni"
        if (( DRY_RUN )); then
            ui_sub "[dry-run] add to crontab: $cronline"
            return 0
        fi
        local others
        others=$(autoupdate_crontab_others) || return 1
        { [[ -z $others ]] || printf '%s\n' "$others"; printf '%s\n' "$cronline"; } | crontab -
        ui_ok "Weekly cronjob installed (Sunday 10:00)"
    else
        ui_err "Neither systemd --user nor crontab available."
        return 1
    fi
}
