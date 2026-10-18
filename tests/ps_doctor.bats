#!/usr/bin/env bats
# PowerShell --doctor, run through pwsh where it is installed.

load ps_helper

# Doctor-Run with ping refused (github.com drops ICMP), $1 MB free on the
# system drive, and every HTTPS request recorded in $HOME/web.
doctor_ps() {
    ps ". (Join-Path \$env:PSLIB 'Summary.ps1'); . (Join-Path \$env:PSLIB 'state/History.ps1'); . (Join-Path \$env:PSLIB 'system/Reboot.ps1'); . (Join-Path \$env:PSLIB 'Doctor.ps1')
        function Test-Connection { \$false }
        function Get-PSDrive { [pscustomobject]@{ Free = $1 * 1MB } }
        function Invoke-WebRequest { param(\$Uri, \$Method, \$TimeoutSec, [switch]\$UseBasicParsing)
            Add-Content '$HOME/web' \"\$Method \$Uri \$TimeoutSec\"
            if (\$env:WEB_DOWN) { throw 'unreachable' } }
        $2
        \$rc = Doctor-Run; \"rc=\$rc\""
}

@test "ps: doctor checks the network with an HTTPS request, not a ping" {
    run doctor_ps 50000 ''
    [ "$status" -eq 0 ]
    [[ "$output" == *"network: reachable"* ]]
    [[ "$output" == *"rc=0"* ]]
    [ "$(cat "$HOME/web")" = "Head https://github.com 4" ]
    run env WEB_DOWN=1 bash -c "$(declare -f ps doctor_ps); doctor_ps 50000 ''"
    [[ "$output" == *"network: github.com unreachable"* ]]
    [[ "$output" == *"rc=1"* ]]
}

@test "ps: doctor disk threshold follows DISK_MIN_FREE_MB" {
    run doctor_ps 1500 '$script:DISK_MIN_FREE_MB = 1024'
    [ "$status" -eq 0 ]
    [[ "$output" == *"disk: 1500MB free"* ]]
    [[ "$output" == *"rc=0"* ]]
    run doctor_ps 1500 '$script:DISK_MIN_FREE_MB = 2048'
    [[ "$output" == *"low disk space"*"1500MB free"* ]]
    [[ "$output" == *"rc=1"* ]]
}
