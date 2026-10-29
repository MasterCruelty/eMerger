#!/usr/bin/env bash
# --deep-clean, Containers section: what docker (every local context) and
# podman keep without using it. Every task asks first unless -y. Stopped
# containers (toolbox, distrobox) and unused volumes hold data: never offered
# under -y. Remote contexts (ssh://, tcp://) are left alone.

# Offer to prune stopped containers, unused images, build cache and unused
# volumes of every local docker context and of podman, then add the
# growth of free space on / to SUMMARY_FREED_KB. Silent when neither tool is
# installed or DEEP_CLEAN_SKIP lists both.
clean_containers() {
    local -a engines=()
    local bin context endpoint free_before
    for bin in docker podman; do
        if sys_has "$bin" && ! _deep_is_skipped "$bin"; then engines+=("$bin"); fi
    done
    (( ${#engines[@]} > 0 )) || return 0
    ui_title "Containers"
    _DEEP_TASK_COUNT=0
    free_before=$(sys_free_space k /)

    for bin in "${engines[@]}"; do
        if [[ $bin == docker ]]; then
            # On fd 3: a probe or prune reading stdin cannot eat the list.
            while IFS='|' read -r context endpoint <&3; do
                if [[ -n $endpoint && $endpoint != unix://* && $endpoint != npipe://* ]]; then
                    ui_muted "docker ($context): remote engine at $endpoint, skipped"
                else
                    _containers_target docker "$context"
                fi
            done 3< <(_containers_docker_contexts)
            _containers_desktop_note
        else
            _containers_target "$bin" ""
        fi
    done

    if (( _DEEP_TASK_COUNT == 0 )); then
        ui_ok "nothing to clean"
        return 0
    fi
    _deep_report_freed "$free_before"
    return 0
}

# Print the docker contexts as name|endpoint, one per line, or one empty line
# when docker lists none (an engine older than contexts, or a failing call).
_containers_docker_contexts() {
    local list
    list=$(docker context ls --format '{{.Name}}|{{.DockerEndpoint}}' 2>/dev/null || true)
    if [[ -z $list ]]; then
        printf '\n'
    else
        printf '%s\n' "$list"
    fi
}

# Print the command line reaching engine $1 through docker context $2 (none
# when empty), one word per line: plain if the daemon answers, else sudo
# (probed with sudo -n, never under --dry-run, where sudo is assumed). Only
# the Linux system docker daemon (no context or "default") is tried through
# sudo: other contexts are user sockets, and root's podman has its own
# storage. Empty when the daemon is not reachable.
_containers_cmd() {
    local -a base=("$1")
    [[ -n $2 ]] && base+=(--context "$2")
    if "${base[@]}" info >/dev/null 2>&1; then
        printf '%s\n' "${base[@]}"
    elif sys_is_root || [[ $1 != docker || ( -n $2 && $2 != default ) ]] || sys_is_macos; then
        return 0
    elif (( DRY_RUN )) || sudo -n "${base[@]}" info >/dev/null 2>&1; then
        printf '%s\n' sudo "${base[@]}"
    fi
    return 0
}

# Set _containers_target's free_images, free_containers, free_volumes and
# free_build to the reclaimable sizes `system df` reports through command
# $@ ("4.978GB"), empty for a kind it does not list.
_containers_reclaimable() {
    local type value
    free_images="" free_containers="" free_volumes="" free_build=""
    while IFS='|' read -r type value; do
        value=${value%% (*}
        case "$type" in
            Images)        free_images=$value ;;
            Containers)    free_containers=$value ;;
            'Local Volumes') free_volumes=$value ;;
            'Build Cache') free_build=$value ;;
        esac
    done < <("$@" system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null || true)
    return 0
}

# Offer the prune tasks of engine $1 through docker context $2 (empty for
# podman or an engine without contexts), each with its reclaimable size.
# A kind reclaiming 0B is not offered.
_containers_target() {
    local bin="$1" context="$2" name="$1"
    [[ -n $context && $context != default ]] && name="$bin ($context)"
    local -a command=()
    mapfile -t command < <(_containers_cmd "$bin" "$context")
    if (( ${#command[@]} == 0 )); then
        if [[ -n $context && $context != default ]]; then
            ui_muted "$name: daemon not running, skipped"
        elif [[ $bin == docker ]]; then
            ui_muted "$name: daemon not reachable (not in the docker group?), skipped"
        else
            ui_muted "$name: not reachable, skipped"
        fi
        return 0
    fi

    local free_images="" free_containers="" free_volumes="" free_build="" read_sizes=1
    # Under --dry-run a sudo command line is not run, not even to read.
    [[ ${command[0]} == sudo ]] && (( DRY_RUN )) && read_sizes=0
    (( read_sizes )) && _containers_reclaimable "${command[@]}"
    _containers_offer "$bin" "Remove stopped $name containers (their files are lost)" "$free_containers" \
        "$name stopped containers kept under -y: they hold files" "${command[@]}" container prune -f
    # Pruned containers free their images and volumes: read the sizes again.
    if (( read_sizes && ! ARG_YES )) && [[ $free_containers != 0B ]]; then
        _containers_reclaimable "${command[@]}"
    fi
    _containers_offer "$bin" "Remove unused $name images" "$free_images" "" \
        "${command[@]}" image prune -af
    if [[ $bin == docker ]]; then
        _containers_offer "$bin" "Clear $name build cache" "$free_build" "" \
            "${command[@]}" builder prune -af
    fi
    # podman volume prune has no -a: it always removes every unused volume.
    local -a volume_args=(volume prune -f)
    [[ $bin == docker ]] && volume_args=(volume prune -af)
    _containers_offer "$bin" "Remove unused $name volumes (their data is lost)" "$free_volumes" \
        "$name unused volumes kept under -y: they hold data" "${command[@]}" "${volume_args[@]}"
    return 0
}

# Offer task $2 of DEEP_CLEAN_SKIP key $1 running command $5... with
# reclaimable size $3 in its detail ("?" when unknown). Nothing when $3 is
# 0B. A non-empty $4 makes the task ask even under -y: there it prints $4.
_containers_offer() {
    local key="$1" label="$2" free="$3" kept="$4"; shift 4
    [[ $free == 0B ]] && return 0
    if [[ -n $kept ]]; then
        _deep_task_asked "$key" "$label" "(reclaimable: ${free:-?})" "$kept" "$@"
    else
        _deep_task "$key" "$label" "(reclaimable: ${free:-?})" "$@"
    fi
}

# Report the size of Docker Desktop's data (~/.docker/desktop on Linux,
# ~/Library/Containers/com.docker.docker on macOS) when it holds 1M or more:
# its disk image does not shrink when the engine prunes, only from Docker
# Desktop.
_containers_desktop_note() {
    local dir kb
    for dir in "$HOME/.docker/desktop" "$HOME/Library/Containers/com.docker.docker"; do
        [[ -d $dir ]] || continue
        kb=$(_clean_size_kb "$dir")
        (( kb >= 1024 )) || continue
        ui_muted "Docker Desktop keeps $(_clean_format_kb "$kb") in $dir: shrink it from Docker Desktop (Troubleshoot, Clean / Purge data)"
    done
    return 0
}
