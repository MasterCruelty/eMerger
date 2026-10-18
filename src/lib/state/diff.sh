#!/usr/bin/env bash
# Package lists before and after a run, and the diff between them.

# Read by the entry point.
# shellcheck disable=SC2034
DIFF_BEFORE="$EMERGER_STATE/pkgs.before"
DIFF_AFTER="$EMERGER_STATE/pkgs.after"
DIFF_LAST="$EMERGER_STATE/pkgs.diff"

# Write every installed package to file $1, sorted, as "source<TAB>name<TAB>
# version" lines, source being apt (dpkg), pacman, rpm, flatpak, snap or brew.
# The tools run without the lock fd.
diff_snapshot() {
    local out="$1"
    : >"$out"
    {
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
    } 9>&-
    sort -o "$out" "$out" 2>/dev/null || true
}

# Write the changes from snapshot $1 to snapshot $2 into $3, one line per
# change: "+" added, "-" removed, "~" upgraded ("old -> new"). Versions are
# compared as sets per manager and name, so a package installed in several
# versions (rpm kernels) yields only the versions that came or went, and "~"
# only when exactly one version left and one arrived.
diff_compute() {
    local before="$1" after="$2" out="$3"
    : >"$out"
    [[ -f $before && -f $after ]] || return 0
    # Read the before file in BEGIN: an NR == FNR test would also hold for
    # the after file when the before file is empty.
    _DIFF_BEFORE="$before" awk -F'\t' -v OFS='\t' '
        BEGIN {
            src = ENVIRON["_DIFF_BEFORE"]
            while ((getline line < src) > 0) {
                split(line, f, "\t")
                if (f[2] == "") continue
                k = f[1] OFS f[2]; e = k OFS f[3]
                if (!(e in b)) { b[e] = 1; bl[k] = bl[k] "\037" f[3] }
            }
            close(src)
        }
        $2 == "" { next }
        { k = $1 OFS $2; e = k OFS $3 }
        !(e in a) { a[e] = 1; al[k] = al[k] "\037" $3 }
        END {
            for (k in bl) if (!(k in al)) al[k] = ""
            for (k in al) {
                nr = 0; na = 0
                n = split(substr(bl[k], 2), v, "\037")
                for (i = 1; i <= n; i++) if (!((k OFS v[i]) in a)) rv[++nr] = v[i]
                n = split(substr(al[k], 2), v, "\037")
                for (i = 1; i <= n; i++) if (!((k OFS v[i]) in b)) av[++na] = v[i]
                if (nr == 1 && na == 1) { print 3, "~", k, rv[1] " -> " av[1]; continue }
                for (i = 1; i <= na; i++) print 1, "+", k, av[i]
                for (i = 1; i <= nr; i++) print 2, "-", k, rv[i]
            }
        }' "$after" | LC_ALL=C sort -t$'\t' -k1,1n -k3,3 -k4,4 -k5,5 | cut -f2- >>"$out"
}

# Print the added, removed and upgraded counts of diff file $1 (default
# DIFF_LAST), then each change, or that none is recorded. Package names and
# versions come from outside and are stripped of terminal controls.
diff_show() {
    local file="${1:-$DIFF_LAST}"
    if [[ ! -s $file ]]; then
        ui_muted "No package changes recorded."
        return
    fi
    ui_title "Package changes"
    local added removed upgraded
    added=$(grep -c '^+' "$file" || true)
    removed=$(grep -c '^-' "$file" || true)
    upgraded=$(grep -c '^~' "$file" || true)
    printf '  %s+%s %d added   %s-%s %d removed   %s~%s %d upgraded\n\n' \
        "$C_GREEN" "$C_RESET" "${added:-0}" \
        "$C_RED"   "$C_RESET" "${removed:-0}" \
        "$C_YELLOW" "$C_RESET" "${upgraded:-0}"
    run_sanitize <"$file" | awk -F'\t' '
        $1=="~"{printf "  \033[33m~\033[0m %-10s %-30s %s\n", $2, $3, $4}
        $1=="+"{printf "  \033[32m+\033[0m %-10s %-30s %s\n", $2, $3, $4}
        $1=="-"{printf "  \033[31m-\033[0m %-10s %-30s %s\n", $2, $3, $4}
    '
}

# Print the number of changes in diff file $1 (default DIFF_LAST), 0 when
# it is missing or empty.
diff_count_changed() {
    local file="${1:-$DIFF_LAST}"
    [[ -s $file ]] || { echo 0; return; }
    wc -l <"$file"
}
