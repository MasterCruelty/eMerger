#!/usr/bin/env bash
# Self-update of a git checkout (git pull --ff-only).

# Fast-forward the git checkout at $1 and print the commits pulled. Return 1
# when it is not a checkout, git is missing, or the fetch or pull fails.
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
    if ! git -C "$root" fetch --quiet 9>&-; then
        ui_err "git fetch failed"
        return 1
    fi
    if ! git -C "$root" pull --ff-only --quiet 9>&-; then
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
