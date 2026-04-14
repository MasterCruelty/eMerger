# fish completion for eMerger
function __up_profiles
    for d in ~/.config/emerger/profiles.d (status dirname)/../share/profiles
        test -d $d; and for f in $d/*.sh
            basename $f .sh
        end
    end | sort -u
end

complete -c up -s h -l help          -d 'show help'
complete -c up -s V -l version       -d 'show version'
complete -c up -s i -l interactive   -d 'interactive menu'
complete -c up      -l doctor        -d 'environment health check'
complete -c up -s n -l dry-run       -d 'dry-run'
complete -c up -s v -l verbose       -d 'verbose output'
complete -c up -s q -l quiet         -d 'quieter output'
complete -c up -s y -l yes           -d 'assume yes'
complete -c up      -l security      -d 'security updates only'
complete -c up      -l firmware      -d 'include firmware'
complete -c up      -l no-firmware   -d 'skip firmware'
complete -c up      -l dev           -d 'include dev toolchains'
complete -c up      -l parallel      -d 'parallel user-space'
complete -c up      -l no-emoji      -d 'ASCII glyphs only'
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
complete -c up      -l report        -d 'export markdown' -r
complete -c up      -l errors        -d 'show errors'
complete -c up      -l self-update   -d 'update eMerger'
complete -c up      -l auto-update   -d 'install auto-update'
complete -c up      -l rebuild-cache -d 'clear detection cache'
