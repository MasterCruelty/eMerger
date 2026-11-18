#!/usr/bin/env bash
# Deep clean, Build artifacts section: the target directories of Rust
# projects under BUILD_SCAN_ROOTS, what `cargo clean` removes. Hidden
# directories and node_modules are not searched. Never offered under -y:
# the next build starts from scratch.

# Directories searched for Rust projects, separated by ":".
: "${BUILD_SCAN_ROOTS:=$HOME}"

# Smallest target directory offered, in KiB.
_BUILDS_MIN_KB=1024

# Offer the Rust target directories found, biggest first, then add the
# growth of free space on / to SUMMARY_FREED_KB. Silent when none is found
# or DEEP_CLEAN_SKIP lists cargo.
clean_builds() {
    # The menu arrays are read and filled by _deep_menu_read and _deep_menu.
    # shellcheck disable=SC2034
    local -a menu_names=() menu_kb=() menu_notes=() menu_refs=()
    local free_before
    _deep_is_skipped cargo && return 0
    _deep_menu_read < <(_builds_rows)
    (( ${#menu_names[@]} > 0 )) || return 0
    ui_title "Build artifacts"
    _DEEP_TASK_COUNT=0
    free_before=$(sys_free_space k /)
    _deep_menu cargo "Clean which?" \
        "${#menu_names[@]} Rust build directories kept under -y: the next build would start from scratch" \
        _builds_remove
    (( _DEEP_TASK_COUNT > 0 )) && _deep_report_freed "$free_before"
    return 0
}

# Print each directory named target under the BUILD_SCAN_ROOTS that cargo
# made (it holds CACHEDIR.TAG and sits beside a Cargo.toml), not descending
# into hidden directories, node_modules or a target directory.
_builds_targets() {
    local root
    local -a roots=()
    IFS=: read -r -a roots <<<"$BUILD_SCAN_ROOTS"
    for root in ${roots[@]+"${roots[@]}"}; do
        [[ -n $root && -d $root ]] || continue
        find "$root" -xdev -mindepth 1 \( -name '.?*' -o -name node_modules \) -prune \
            -o -type d -name target -prune -print 2>/dev/null || true
    done | while IFS= read -r dir; do
        [[ -f $dir/CACHEDIR.TAG && -f ${dir%/*}/Cargo.toml ]] && printf '%s\n' "$dir"
    done
    return 0
}

# Print a menu row "KiB<TAB>project<TAB>note<TAB>target dir" for each target
# directory of _builds_targets holding _BUILDS_MIN_KB or more. The note
# dates the last build from .rustc_info.json, which every cargo build
# rewrites, else from the directory.
_builds_rows() {
    local dir kb project stamp
    while IFS= read -r dir; do
        kb=$(_clean_size_kb "$dir")
        (( kb >= _BUILDS_MIN_KB )) || continue
        project=${dir%/*}
        [[ $project == "$HOME"/* ]] && project='~'"/${project#"$HOME"/}"
        stamp="$dir/.rustc_info.json"
        [[ -f $stamp ]] || stamp=$dir
        printf '%s\t%s\t%s\t%s\n' "$kb" "$project" \
            "built $(_deep_days_since "$(_deep_mtime "$stamp")") days ago" "$dir"
    done < <(_builds_targets)
}

# Remove target directory $1 of project $2, as `cargo clean` does.
_builds_remove() {
    run_cmd "Clean $2" rm -rf -- "$1" || true
    return 0
}
