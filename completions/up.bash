# bash completion for eMerger
# Scope: every flag the Unix parser accepts as its own word, manager names
# after --only and --except, profile names after --profile.

# Print the checkout root the `up` alias points at, or nothing. The alias body
# is `bash "<root>/src/emerger.sh"`, quoted or not.
_up_root() {
    local alias_def="${BASH_ALIASES[up]:-}"
    # bash 3.2 has no BASH_ALIASES: read the definition `alias up` prints.
    [[ -n $alias_def ]] || alias_def=$(alias up 2>/dev/null)
    [[ $alias_def == *"/src/emerger.sh"* ]] || return 0
    alias_def="${alias_def%%/src/emerger.sh*}"
    alias_def="${alias_def#*bash }"
    alias_def="${alias_def#[\"\']}"
    printf '%s' "${alias_def//\\ / }"
}

# Fill COMPREPLY with the profile names starting with $1. Names come from file
# names, so they are matched as text and never expanded. Seen names are a
# newline-delimited string, since bash 3.2 has no associative arrays.
_up_profiles() {
    local cur="$1" dir file name root
    local seen=$'\n'
    root=$(_up_root)
    COMPREPLY=()
    for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/emerger/profiles.d" ${root:+"$root/share/profiles"}; do
        [[ -d $dir ]] || continue
        for file in "$dir"/*.sh; do
            [[ -f $file ]] || continue
            name="${file##*/}"; name="${name%.sh}"
            [[ $name == "$cur"* && $seen != *$'\n'"$name"$'\n'* ]] || continue
            seen+="$name"$'\n'
            COMPREPLY+=("$name")
        done
    done
}

# Fill COMPREPLY with the lines command $@ prints, one word per line, so file
# names keep their spaces. A read loop, since bash 3.2 has no mapfile.
_up_reply() {
    local word
    COMPREPLY=()
    while IFS= read -r word; do
        COMPREPLY+=("$word")
    done < <("$@")
}

# Fill COMPREPLY for the word under the cursor: profile names after
# --profile, files after --metrics, manager names after --only and --except, else flags.
_up_completion() {
    local cur prev opts
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile)
            _up_profiles "$cur"
            return 0
            ;;
        --metrics)
            _up_reply compgen -f -- "$cur"
            return 0
            ;;
        --only|--except)
            # Complete the item after the last comma, keep the ones before it.
            local pre=""
            [[ $cur == *,* ]] && pre="${cur%,*},"
            _up_reply compgen -P "$pre" -W "pacman yay paru apt dnf yum zypper xbps apk eopkg emerge nix softwareupdate brew mas fwupd rpi-eeprom flatpak snap rustup cargo npm pnpm pip gem" -- "${cur##*,}"
            return 0
            ;;
    esac

    opts="-h --help -V --version --doctor
          -n --dry-run -v --verbose -q -qq -qqq --quiet -y --yes --json
          --security --accept-licenses --firmware --no-firmware --dev --parallel --ascii
          --profile --list-profiles --only --except
          --snapshot --rollback --refresh-mirrors --resume --reboot --reboot-exit
          --download-only
          -nl --no-logo -ni --no-info -nc --keep-cache -nt --keep-trash --deep-clean -w --weather
          --changed --changelog --history --metrics -err --errors
          -up --self-update -au --auto-update -rc --rebuild-cache"
    _up_reply compgen -W "$opts" -- "$cur"
}
complete -F _up_completion up
