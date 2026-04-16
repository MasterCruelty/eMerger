#!/usr/bin/env bash
# Extract a short one-line stat from a command's captured output.
# Used to produce a collapsed summary at end of each step.

progress_summarize() {
    local mgr="$1" file="$2"
    [[ -f $file ]] || { printf ''; return; }
    case "$mgr" in
        apt)
            awk '/[0-9]+ upgraded/{for(i=1;i<=NF;i++)if($i=="upgraded,"){u=$(i-1)} for(i=1;i<=NF;i++)if($i=="newly"){n=$(i-1)} for(i=1;i<=NF;i++)if($i=="remove."){r=$(i-1)} printf "%s upgraded, %s new, %s removed", u+0, n+0, r+0; exit}' "$file"
            ;;
        pacman|yay|paru)
            local pkgs
            pkgs=$(grep -E '^Packages \([0-9]+\)' "$file" | tail -n1 | sed -E 's/^Packages \(([0-9]+)\).*/\1/')
            [[ -n $pkgs ]] && printf '%s packages' "$pkgs"
            ;;
        dnf|yum)
            awk '/^Upgrade +[0-9]+ Package/{print $2" upgraded"; exit} /^Install +[0-9]+ Package/{ins=$2} END{if(ins)print ins" installed"}' "$file"
            ;;
        flatpak)
            grep -cE '^Updating|^Installing' "$file" | awk '{if($1>0)print $1" refreshed"}'
            ;;
        snap)
            grep -cE 'refreshed' "$file" | awk '{if($1>0)print $1" refreshed"}'
            ;;
        *) : ;;
    esac
}

progress_highlight() {
    # Colorize common error keywords in a stream.
    sed -E \
        -e "s/(ERROR|Error|error)/$(printf '\033[31m')\1$(printf '\033[0m')/g" \
        -e "s/(WARNING|Warning|warning|WARN)/$(printf '\033[33m')\1$(printf '\033[0m')/g" \
        -e "s/^(E: .*)/$(printf '\033[31m')\1$(printf '\033[0m')/g" \
        -e "s/^(W: .*)/$(printf '\033[33m')\1$(printf '\033[0m')/g"
}
