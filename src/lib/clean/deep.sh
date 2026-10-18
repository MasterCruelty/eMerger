#!/usr/bin/env bash
# --deep-clean: system leftovers a normal run does not touch. Every task
# asks first unless -y.

# --deep-clean. Task names for DEEP_CLEAN_SKIP:
# journal kernels residual snap docker podman coredumps npm go
: "${JOURNAL_MAX_SIZE:=200M}"
: "${DEEP_CLEAN_SKIP:=}"

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

# Print the docker/podman command line for $1, one word per line: plain if
# the daemon answers, else sudo (probed with sudo -n, never under --dry-run,
# where sudo is assumed). Empty when the daemon is not reachable.
_deep_container_cmd() {
    local bin="$1"
    if "$bin" info >/dev/null 2>&1; then
        printf '%s' "$bin"
    elif sys_is_root; then
        return 0
    elif (( DRY_RUN )) || sudo -n "$bin" info >/dev/null 2>&1; then
        printf 'sudo\n%s' "$bin"
    fi
}

# Offer each --deep-clean task that has something to remove, then add the
# growth of free space on / to SUMMARY_FREED_KB (not under --dry-run).
clean_deep() {
    local sudo_cmd free_before free_after
    sudo_cmd=$(sys_sudo_prefix)
    ui_title "Deep clean"
    _DEEP_TASK_COUNT=0
    free_before=$(sys_free_space k /)

    _deep_journal
    _deep_kernels
    _deep_residual
    _deep_snap
    _deep_containers
    _deep_coredumps
    _deep_devcaches

    if (( _DEEP_TASK_COUNT == 0 )); then
        ui_ok "nothing to clean"
        return 0
    fi
    free_after=$(sys_free_space k /)
    if [[ -n $free_before && -n $free_after ]] && (( ! DRY_RUN )) && (( free_after > free_before )); then
        SUMMARY_FREED_KB=$(( SUMMARY_FREED_KB + free_after - free_before ))
        ui_ok "freed $(_clean_format_kb $(( free_after - free_before ))) on /"
    fi
    return 0
}

# Deep clean tasks, called by clean_deep only: each reads its local sudo_cmd
# (privilege prefix) and returns 0, offered or not.

# Offer to shrink the systemd journal to JOURNAL_MAX_SIZE when it is larger.
_deep_journal() {
    if sys_has journalctl; then
        local usage
        # "take up 1.5G" or, under 1 KiB, "take up 512B".
        usage=$({ journalctl --disk-usage 2>/dev/null || true; } | sed -nE 's/.*take up ([0-9.]+[KMGTPE]?)B?.*/\1/p' | head -n 1)
        if [[ -n $usage ]]; then
            local usage_bytes limit_bytes
            usage_bytes=$(numfmt --from=iec "$usage" 2>/dev/null || echo 0)
            limit_bytes=$(numfmt --from=iec "$JOURNAL_MAX_SIZE" 2>/dev/null || echo 0)
            if (( usage_bytes > limit_bytes )); then
                _deep_task journal "Shrink journal to $JOURNAL_MAX_SIZE" "(now $usage)" \
                    $sudo_cmd journalctl --vacuum-size="$JOURNAL_MAX_SIZE"
            fi
        fi
    fi
    return 0
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

# Offer to prune dangling images and build cache of docker and podman.
_deep_containers() {
    local bin
    for bin in docker podman; do
        sys_has "$bin" || continue
        local -a command=()
        mapfile -t command < <(_deep_container_cmd "$bin")
        if (( ${#command[@]} == 0 )); then
            ui_muted "$bin: daemon not reachable (not in the $bin group?), skipped"
            continue
        fi
        local reclaim=""
        # Under --dry-run a sudo command line is not run, not even to read.
        if [[ ${command[0]} != sudo ]] || (( ! DRY_RUN )); then
            reclaim=$({ "${command[@]}" system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null || true; } | awk -F'|' '
                $1 == "Images" || $1 ~ /^Build/ {
                    v = $2; sub(/ *\(.*/, "", v)
                    printf "%s%s %s", sep, ($1 == "Images" ? "images" : "build cache"), v; sep = ", "
                }')
        fi
        _deep_task "$bin" "Prune $bin dangling images + build cache" "(reclaimable: ${reclaim:-?})" \
            bash -c '"$@" image prune -f && { "$@" builder prune -f 2>/dev/null || true; }' _ "${command[@]}"
    done
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
