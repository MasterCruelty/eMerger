# bash completion for eMerger
_up_completion() {
    local cur prev opts profiles
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    case "$prev" in
        --profile)
            profiles=$(for d in "$HOME/.config/emerger/profiles.d" "$(dirname "$(command -v up 2>/dev/null || echo)")/../share/profiles"; do
                [ -d "$d" ] && for f in "$d"/*.sh; do [ -f "$f" ] && basename "$f" .sh; done
            done | sort -u)
            COMPREPLY=( $(compgen -W "$profiles" -- "$cur") )
            return 0
            ;;
        --report)
            COMPREPLY=( $(compgen -f -- "$cur") )
            return 0
            ;;
    esac

    opts="-h --help -V --version -i --interactive --doctor
          -n --dry-run -v --verbose -q -qq -qqq --quiet -y --yes
          --security --firmware --no-firmware --dev --parallel --no-emoji
          --profile --list-profiles --snapshot --refresh-mirrors --resume --reboot
          -nl --no-logo -ni --no-info -nc --no-cache -nt --no-trash -w --weather
          --changed --changelog --history --report -err --errors
          -up --self-update -au --auto-update -rc --rebuild-cache"
    COMPREPLY=( $(compgen -W "$opts" -- "$cur") )
}
complete -F _up_completion up
