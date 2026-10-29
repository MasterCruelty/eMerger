# fish completion for eMerger
# Scope: every flag the Unix parser accepts as its own word, manager names
# after --only and --except, profile names after --profile.
# Print the profile names from the user's profiles.d and the shipped ones.
function __up_profiles
    set -l config (set -q XDG_CONFIG_HOME; and echo $XDG_CONFIG_HOME; or echo ~/.config)
    set -l dirs $config/emerger/profiles.d
    # Alias `up` holds the checkout path: bash "<root>/src/emerger.sh", quoted or not.
    set -l root (functions up 2>/dev/null | string match -r -g '"?([^" ]*)/src/emerger\.sh')
    set -q root[1]; and set -a dirs $root[1]/share/profiles
    for d in $dirs
        test -d $d; and for f in $d/*.sh
            basename $f .sh
        end
    end | sort -u
end

complete -c up -s h -l help          -d 'show help'
complete -c up -s V -l version       -d 'show version'
complete -c up      -l doctor        -d 'environment health check'
complete -c up -s n -l dry-run       -d 'dry-run'
complete -c up -s v -l verbose       -d 'verbose output'
complete -c up -s q -l quiet         -d 'quieter output'
complete -c up -o qq                 -d 'quieter output'
complete -c up -o qqq                -d 'quietest output'
complete -c up -s y -l yes           -d 'assume yes'
complete -c up      -l security      -d 'security updates only'
complete -c up      -l accept-licenses -d 'accept licence agreements'
complete -c up      -l firmware      -d 'include firmware'
complete -c up      -l no-firmware   -d 'skip firmware'
complete -c up      -l dev           -d 'include dev toolchains'
complete -c up      -l parallel      -d 'parallel user-space'
complete -c up      -l ascii      -d 'ASCII glyphs only'
complete -c up -o nl -l no-logo       -d 'hide logo'
complete -c up -o ni -l no-info       -d 'hide system info'
complete -c up -o nc -l keep-cache      -d 'skip cache cleaning and the deleted-but-open files warning'
complete -c up -o nt -l keep-trash      -d 'skip trash cleaning'
complete -c up      -l json          -d 'JSON summary on stdout'
complete -c up      -l only          -d 'only these managers' -xa 'pacman yay paru apt dnf yum zypper xbps apk eopkg emerge nix softwareupdate brew mas fwupd rpi-eeprom flatpak snap rustup cargo npm pnpm pip gem'
complete -c up      -l except        -d 'skip these managers' -xa 'pacman yay paru apt dnf yum zypper xbps apk eopkg emerge nix softwareupdate brew mas fwupd rpi-eeprom flatpak snap rustup cargo npm pnpm pip gem'
complete -c up      -l rollback      -d 'revert last snapshot'
complete -c up      -l reboot-exit   -d 'exit 4 if reboot required'
complete -c up      -l download-only -d 'download, do not install'
complete -c up      -l metrics       -d 'export Prometheus textfile' -r
complete -c up      -l deep-clean    -d 'journal, old kernels, containers'
complete -c up      -l profile       -d 'load profile' -xa '(__up_profiles)'
complete -c up      -l list-profiles -d 'list profiles'
complete -c up      -l snapshot      -d 'pre-update snapshot'
complete -c up      -l refresh-mirrors -d 'refresh mirrors'
complete -c up      -l resume        -d 'resume interrupted run'
complete -c up      -l reboot        -d 'reboot if required'
complete -c up -s w -l weather       -d 'weather line'
complete -c up      -l changed       -d 'show package diff'
complete -c up      -l changelog     -d 'show changelog' -x
complete -c up      -l history       -d 'run history'
complete -c up -o err -l errors      -d 'show errors'
complete -c up -o up -l self-update  -d 'update eMerger'
complete -c up -o au -l auto-update  -d 'install auto-update'
complete -c up -o rc -l rebuild-cache -d 'clear detection cache'
