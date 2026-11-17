#!/usr/bin/env bash
# Deep clean, run by default unless --soft-clean: system leftovers, offered
# one task at a time. Every task asks first unless -y. The Containers, AI
# models and Build artifacts sections (clean/containers.sh, clean/ai.sh,
# clean/builds.sh) share these helpers.

# Task names for DEEP_CLEAN_SKIP: journal syslog kernels residual snap
# coredumps npm go docker podman ollama huggingface cargo
: "${DEEP_CLEAN_SKIP:=}"

# Plain-text system logs _deep_syslog offers to empty: the files rsyslog
# writes and the copy logrotate leaves uncompressed.
_DEEP_SYSLOG_FILES=(/var/log/syslog /var/log/syslog.1 /var/log/messages /var/log/messages.1
                    /var/log/user.log /var/log/user.log.1)

# Return 0 when task key $1 is listed in DEEP_CLEAN_SKIP (comma, space or
# tab separated, compared literally).
_deep_is_skipped() {
    local key
    local -a keys=()
    # read -a splits without pathname expansion: a key never globs the cwd.
    IFS=$', \t\n' read -r -a keys <<<"${DEEP_CLEAN_SKIP:-}"
    for key in ${keys[@]+"${keys[@]}"}; do [[ $key == "$1" ]] && return 0; done
    return 1
}

# Ask "label $2?" with detail $3 and run command $4... on yes, under label $2.
# Skip silently when DEEP_CLEAN_SKIP lists task key $1, else count the offer
# in _DEEP_TASK_COUNT.
_deep_task() {
    local key="$1" label="$2" detail="$3"; shift 3
    _deep_is_skipped "$key" && return 0
    _DEEP_TASK_COUNT=$(( _DEEP_TASK_COUNT + 1 ))
    if ui_confirm "$label?" n "$detail"; then
        run_cmd "$label" "$@" || true
    else
        ui_muted "skipped"
    fi
}

# _deep_task running command $5... for data the user may want: never
# offered under -y, where message $4 is printed instead.
_deep_task_asked() {
    local key="$1" label="$2" detail="$3" kept="$4"; shift 4
    _deep_is_skipped "$key" && return 0
    if (( ARG_YES )); then
        ui_muted "$kept"
        return 0
    fi
    _deep_task "$key" "$label" "$detail" "$@"
}

# Offer each Deep clean task that has something to remove, then add the
# growth of free space on / to SUMMARY_FREED_KB (not under --dry-run).
clean_deep() {
    local sudo_cmd free_before
    sudo_cmd=$(sys_sudo_prefix)
    ui_title "Deep clean"
    _DEEP_TASK_COUNT=0
    free_before=$(sys_free_space k /)

    _deep_journal
    _deep_syslog
    _deep_kernels
    _deep_residual
    _deep_snap
    _deep_coredumps
    _deep_devcaches

    if (( _DEEP_TASK_COUNT == 0 )); then
        ui_ok "nothing to clean"
        return 0
    fi
    _deep_report_freed "$free_before"
    return 0
}

# Add the growth of free space on / since reading $1 (KiB, from
# sys_free_space) to SUMMARY_FREED_KB and report it. Nothing under
# --dry-run, when $1 is empty or when the space did not grow.
_deep_report_freed() {
    local free_before="$1" free_after
    free_after=$(sys_free_space k /)
    if [[ -n $free_before && -n $free_after ]] && (( ! DRY_RUN )) && (( free_after > free_before )); then
        SUMMARY_FREED_KB=$(( SUMMARY_FREED_KB + free_after - free_before ))
        ui_ok "Freed $(_clean_format_kb $(( free_after - free_before ))) on /"
    fi
    return 0
}

# Offer the rows of the caller's menu_names, menu_kb (KiB) and menu_notes
# as a numbered menu under DEEP_CLEAN_SKIP key $1, asking question $2, and
# call function $4 with the menu_refs entry and the name of each row picked.
# Nothing when the menu is empty or $1 is skipped. Under -y message $3 is
# printed instead: the rows hold data the user may want.
_deep_menu() {
    local key="$1" question="$2" kept="$3" remover="$4" i
    (( ${#menu_names[@]} > 0 )) || return 0
    _deep_is_skipped "$key" && return 0
    if (( ARG_YES )); then
        ui_muted "$kept"
        return 0
    fi
    _DEEP_TASK_COUNT=$(( _DEEP_TASK_COUNT + 1 ))
    for i in "${!menu_names[@]}"; do
        printf '    %s%2d%s  %-36.36s %s%6s%s  %s\n' "$C_MAGENTA" $(( i + 1 )) "$C_RESET" \
            "${menu_names[i]}" "$C_BOLD" "$(_clean_format_kb "${menu_kb[i]}")" "$C_RESET" "${menu_notes[i]}"
    done
    ui_ask "$question" "a/N" "a = all, n = none, or numbers like 1 3 5-7" || true
    _clean_parse_pick "$UI_ANSWER" "${#menu_names[@]}"
    if (( ${#_CLEAN_PICK[@]} == 0 )); then
        ui_muted "skipped"
        return 0
    fi
    for i in "${_CLEAN_PICK[@]}"; do
        "$remover" "${menu_refs[i-1]}" "${menu_names[i-1]}"
    done
    return 0
}

# Fill the caller's menu_names, menu_kb, menu_notes and menu_refs from
# lines "KiB<TAB>name<TAB>note<TAB>ref" on stdin, biggest first.
_deep_menu_read() {
    local kb name note ref
    while IFS=$'\t' read -r kb name note ref; do
        menu_kb+=("$kb"); menu_names+=("$name"); menu_notes+=("$note"); menu_refs+=("$ref")
    done < <(sort -t $'\t' -k1,1nr)
    return 0
}

# Print the days between epoch seconds $1 and now, 0 when $1 is in the future.
_deep_days_since() {
    local now days
    now=$(date +%s)
    days=$(( (now - $1) / 86400 ))
    (( days < 0 )) && days=0
    printf '%d' "$days"
}

# Print the last access time of file $1 in epoch seconds (GNU or BSD stat),
# 0 when it cannot be read.
_deep_atime() {
    stat -c %X -- "$1" 2>/dev/null || stat -f %a -- "$1" 2>/dev/null || echo 0
}

# Print the last modification time of file $1 in epoch seconds (GNU or BSD
# stat), 0 when it cannot be read.
_deep_mtime() {
    stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null || echo 0
}

# Deep clean tasks, called by clean_deep only: each reads its local sudo_cmd
# (privilege prefix) and returns 0, offered or not.

# Offer to empty the systemd journal (rotate, then delete every archived
# file), with its size. Never offered under -y: a log may be needed.
_deep_journal() {
    if sys_has journalctl; then
        local usage usage_bytes
        # "take up 1.5G" or, under 1 KiB, "take up 512B".
        usage=$({ journalctl --disk-usage 2>/dev/null || true; } | sed -nE 's/.*take up ([0-9.]+[KMGTPE]?)B?.*/\1/p' | head -n 1)
        if [[ -n $usage ]]; then
            usage_bytes=$(numfmt --from=iec "$usage" 2>/dev/null || echo 0)
            if (( usage_bytes > 0 )); then
                _deep_task_asked journal "Empty the journal" "(now $usage)" "journal kept under -y" \
                    $sudo_cmd journalctl --rotate --vacuum-time=1s
            fi
        fi
    fi
    return 0
}

# Offer to empty the non-empty system logs of _DEEP_SYSLOG_FILES, with
# their size and the program writing most of the biggest. Never offered
# under -y: a log may be needed. The files are truncated, not deleted:
# rsyslog keeps them open.
_deep_syslog() {
    local file bytes total=0 top=0 biggest="" writer
    local -a logs=()
    for file in "${_DEEP_SYSLOG_FILES[@]}"; do
        [[ -f $file ]] || continue
        bytes=$(stat -c %s -- "$file" 2>/dev/null || stat -f %z -- "$file" 2>/dev/null || echo 0)
        (( bytes > 0 )) || continue
        logs+=("$file"); total=$(( total + bytes ))
        if (( bytes > top )); then top=$bytes; biggest=$file; fi
    done
    (( ${#logs[@]} > 0 )) || return 0
    writer=$(_deep_log_writer "$biggest")
    printf -v file '%s, ' "${logs[@]}"
    _deep_task_asked syslog "Empty system logs" \
        "($(_clean_format_kb $(( total / 1024 ))) in ${file%, }${writer:+, mostly from $writer})" \
        "system logs kept under -y" $sudo_cmd truncate -s 0 "${logs[@]}"
    return 0
}

# Print the program that wrote more than half of the last MiB of syslog
# file $1 (ISO or classic timestamps), empty when none did or the file
# cannot be read.
_deep_log_writer() {
    { tail -c 1048576 -- "$1" 2>/dev/null || true; } | awk '
        { prog = ($1 ~ /^[0-9][0-9][0-9][0-9]-/) ? $3 : $5
          sub(/\[.*/, "", prog); sub(/:$/, "", prog)
          if (prog != "") count[prog]++
          lines++ }
        END { for (p in count) if (count[p] * 2 > lines) print p }'
}

# Offer to remove installed kernels beyond the newest two (dnf, zypper).
_deep_kernels() {
    if sys_has dnf; then
        local old_count
        old_count=$({ dnf repoquery --installonly --latest-limit=-2 -q 2>/dev/null || true; } | wc -l)
        (( old_count > 0 )) && _deep_task kernels "Remove old kernels" "($old_count packages, keeps 2)" \
            $sudo_cmd dnf remove -y --oldinstallonly --setopt installonly_limit=2
    elif sys_has zypper; then
        _deep_task kernels "Purge old kernels" "(zypper purge-kernels)" $sudo_cmd zypper --non-interactive purge-kernels
    fi
    return 0
}

# Offer to purge the configs dpkg keeps for removed packages (state "rc").
_deep_residual() {
    if sys_has dpkg-query; then
        local -a rc_pkgs=()
        mapfile -t rc_pkgs < <(dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 2>/dev/null | awk '$1=="rc"{print $2}')
        if (( ${#rc_pkgs[@]} > 0 )); then
            _deep_task residual "Purge leftover configs" "(${#rc_pkgs[@]} removed packages)" \
                $sudo_cmd dpkg --purge "${rc_pkgs[@]}"
        fi
    fi
    return 0
}

# Offer to remove the disabled revisions snap keeps, often GBs of them.
_deep_snap() {
    if sys_has snap; then
        local -a revisions=()
        mapfile -t revisions < <(snap list --all 2>/dev/null | awk '/disabled/{print $1" "$3}')
        if (( ${#revisions[@]} > 0 )); then
            local -a rev_args=() revision
            for revision in "${revisions[@]}"; do rev_args+=("${revision%% *}" "${revision##* }"); done
            _deep_task snap "Remove disabled snap revisions" "(${#revisions[@]})" \
                bash -c 'sc=$1; shift; while (( $# >= 2 )); do $sc snap remove "$1" --revision="$2" || exit 1; shift 2; done' \
                _ "$sudo_cmd" "${rev_args[@]}"
        fi
    fi
    return 0
}

# Offer to delete systemd crash dumps.
_deep_coredumps() {
    if [[ -d /var/lib/systemd/coredump ]]; then
        local core_count
        core_count=$({ find /var/lib/systemd/coredump -type f 2>/dev/null || true; } | wc -l)
        (( core_count > 0 )) && _deep_task coredumps "Delete crash dumps" "($core_count files)" \
            $sudo_cmd find /var/lib/systemd/coredump -type f -delete
    fi
    return 0
}

# Offer to clean the npm and Go caches kept outside ~/.cache.
_deep_devcaches() {
    if sys_has npm && [[ -d $HOME/.npm/_cacache ]]; then
        _deep_task npm "Clean npm cache" "($(_clean_size_human "$HOME/.npm/_cacache"))" npm cache clean --force
    fi
    if sys_has go; then
        local gocache; gocache=$(go env GOCACHE 2>/dev/null || true)
        [[ -n $gocache && -d $gocache && $gocache != "$HOME/.cache/"* ]] && \
            _deep_task go "Clean Go build cache" "($(_clean_size_human "$gocache"))" go clean -cache
    fi
    return 0
}
