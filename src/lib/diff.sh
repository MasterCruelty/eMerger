#!/usr/bin/env bash
# Snapshot installed packages before/after; compute diff on demand.

: "${DIFF_BEFORE:=$EMERGER_STATE/pkgs.before}"
: "${DIFF_AFTER:=$EMERGER_STATE/pkgs.after}"
: "${DIFF_LAST:=$EMERGER_STATE/pkgs.diff}"

diff_snapshot() {
    local out="$1"
    : >"$out"
    if sys_has dpkg-query; then
        dpkg-query -W -f='apt\t${Package}\t${Version}\n' 2>/dev/null >>"$out"
    fi
    if sys_has pacman; then
        pacman -Q 2>/dev/null | awk '{print "pacman\t"$1"\t"$2}' >>"$out"
    fi
    if sys_has rpm; then
        rpm -qa --qf 'rpm\t%{NAME}\t%{VERSION}-%{RELEASE}\n' 2>/dev/null >>"$out"
    fi
    if sys_has flatpak; then
        flatpak list --columns=application,version 2>/dev/null | awk -F'\t' 'NR>1 || tolower($1) !~ /^application$/ {if ($1!="") print "flatpak\t"$1"\t"$2}' >>"$out"
    fi
    if sys_has snap; then
        snap list 2>/dev/null | tail -n +2 | awk '{print "snap\t"$1"\t"$2}' >>"$out"
    fi
    if sys_has brew; then
        brew list --versions 2>/dev/null | awk '{print "brew\t"$1"\t"$2}' >>"$out"
    fi
    sort -o "$out" "$out" 2>/dev/null || true
}

diff_compute() {
    local before="$1" after="$2" out="$3"
    : >"$out"
    [[ -f $before && -f $after ]] || return 0
    trap 'rm -f "${out}.a" "${out}.b"' RETURN
    # Build maps by "mgr\tname" -> version
    awk -F'\t' '{print $1"\t"$2"\t"$3}' "$before" | sort -u >"${out}.b"
    awk -F'\t' '{print $1"\t"$2"\t"$3}' "$after"  | sort -u >"${out}.a"
    # added
    comm -13 <(awk -F'\t' '{print $1"\t"$2}' "${out}.b") <(awk -F'\t' '{print $1"\t"$2}' "${out}.a") | while IFS=$'\t' read -r mgr name; do
        local v; v=$(awk -F'\t' -v m="$mgr" -v n="$name" '$1==m&&$2==n{print $3; exit}' "${out}.a")
        printf '+\t%s\t%s\t%s\n' "$mgr" "$name" "$v" >>"$out"
    done
    # removed
    comm -23 <(awk -F'\t' '{print $1"\t"$2}' "${out}.b") <(awk -F'\t' '{print $1"\t"$2}' "${out}.a") | while IFS=$'\t' read -r mgr name; do
        local v; v=$(awk -F'\t' -v m="$mgr" -v n="$name" '$1==m&&$2==n{print $3; exit}' "${out}.b")
        printf -- '-\t%s\t%s\t%s\n' "$mgr" "$name" "$v" >>"$out"
    done
    # upgraded: same mgr+name, different version
    join -t$'\t' -j1 <(awk -F'\t' '{print $1"_"$2"\t"$3}' "${out}.b" | sort) \
                    <(awk -F'\t' '{print $1"_"$2"\t"$3}' "${out}.a" | sort) \
        | awk -F'\t' '$2!=$3{split($1,x,"_"); print "~\t"x[1]"\t"x[2]"\t"$2" -> "$3}' >>"$out"
    rm -f "${out}.a" "${out}.b"
}

diff_show() {
    local f="${1:-$DIFF_LAST}"
    if [[ ! -s $f ]]; then
        ui_muted "No package changes recorded."
        return
    fi
    ui_title "Package changes"
    local added removed upgraded
    added=$(grep -c '^+' "$f" || true)
    removed=$(grep -c '^-' "$f" || true)
    upgraded=$(grep -c '^~' "$f" || true)
    printf '  %s+%s %d added   %s-%s %d removed   %s~%s %d upgraded\n\n' \
        "$C_GREEN" "$C_RESET" "${added:-0}" \
        "$C_RED"   "$C_RESET" "${removed:-0}" \
        "$C_YELLOW" "$C_RESET" "${upgraded:-0}"
    awk -F'\t' '
        $1=="~"{printf "  \033[33m~\033[0m %-10s %-30s %s\n", $2, $3, $4}
        $1=="+"{printf "  \033[32m+\033[0m %-10s %-30s %s\n", $2, $3, $4}
        $1=="-"{printf "  \033[31m-\033[0m %-10s %-30s %s\n", $2, $3, $4}
    ' "$f"
}

diff_count_changed() {
    local f="${1:-$DIFF_LAST}"
    [[ -s $f ]] || { echo 0; return; }
    wc -l <"$f"
}
