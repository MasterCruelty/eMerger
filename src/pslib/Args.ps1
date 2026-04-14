# Argument parser. Returns a PSCustomObject with booleans / strings.

function Parse-Args {
    param([string[]]$Argv)
    $o = [pscustomobject]@{
        Help=$false; Version=$false
        DryRun=$false; Verbose=$false; Yes=$false
        Dev=$false; Security=$false; Firmware=$false
        NoLogo=$false; NoInfo=$false; NoCache=$false; NoTrash=$false
        Errors=$false; History=$false; Doctor=$false
        SelfUpdate=$false; AutoUpdate=$false; RebuildCache=$false
        Snapshot=$false; Reboot=$false
        Profile=''; Changelog=''; Report=''
        ListProfiles=$false; NoEmoji=$false; Interactive=$false
        Parallel=$false; Changed=$false; Resume=$false
        Json=$false; RebootExit=$false; DownloadOnly=$false
        Only=''; Except=''; Metrics=''
    }
    if (-not $Argv) { return $o }
    # Expand short-flag bundles: "-nv" -> "-n -v".
    $allowed = 'hVnvqyiw'.ToCharArray()
    $keep = @('-up','-au','-err','-rc','-nl','-ni','-nc','-nt','-qq','-qqq','-xyzzy',
              '-h','-V','-n','-v','-q','-y','-i','-w')
    $expanded = New-Object System.Collections.Generic.List[string]
    foreach ($a in $Argv) {
        $s = [string]$a
        if ($keep -contains $s -or $s.StartsWith('--')) { [void]$expanded.Add($s); continue }
        if ($s -match '^-[A-Za-z]{2,}$') {
            $letters = $s.Substring(1).ToCharArray()
            $all = $true
            foreach ($c in $letters) { if ($allowed -notcontains $c) { $all = $false; break } }
            if ($all) {
                foreach ($c in $letters) { [void]$expanded.Add("-$c") }
                continue
            }
        }
        [void]$expanded.Add($s)
    }
    $Argv = $expanded.ToArray()
    $i = 0
    while ($i -lt $Argv.Count) {
        $a = [string]$Argv[$i]
        switch -Regex -CaseSensitive ($a) {
            '^(-h|--help|-help)$'        { $o.Help = $true }
            '^(-V|--version)$'           { $o.Version = $true }
            '^(-n|--dry-run)$'           { $o.DryRun = $true }
            '^(-v|--verbose)$'           { $o.Verbose = $true; $script:UI_VERBOSE = $true }
            '^(-q|--quiet)$'             { $script:QUIET_LEVEL++ }
            '^-qq$'                      { $script:QUIET_LEVEL = 2 }
            '^-qqq$'                     { $script:QUIET_LEVEL = 3 }
            '^(-y|--yes)$'               { $o.Yes = $true }
            '^--dev$'                    { $o.Dev = $true }
            '^--security$'               { $o.Security = $true }
            '^--firmware$'               { $o.Firmware = $true }
            '^(-nl|--no-logo)$'          { $o.NoLogo = $true }
            '^(-ni|--no-info)$'          { $o.NoInfo = $true }
            '^(-nc|--no-cache)$'         { $o.NoCache = $true }
            '^(-nt|--no-trash)$'         { $o.NoTrash = $true }
            '^(-err|--errors)$'          { $o.Errors = $true }
            '^--history$'                { $o.History = $true }
            '^--doctor$'                 { $o.Doctor = $true }
            '^(-up|--self-update)$'      { $o.SelfUpdate = $true }
            '^(-au|--auto-update)$'      { $o.AutoUpdate = $true }
            '^(-rc|--rebuild-cache)$'    { $o.RebuildCache = $true }
            '^--snapshot$'               { $o.Snapshot = $true }
            '^--reboot$'                 { $o.Reboot = $true }
            '^--list-profiles$'          { $o.ListProfiles = $true }
            '^--no-emoji$'               { $o.NoEmoji = $true; $script:UI_UNICODE = $false }
            '^(-i|--interactive)$'       { $o.Interactive = $true }
            '^--parallel$'               { $o.Parallel = $true }
            '^--changed$'                { $o.Changed = $true }
            '^--resume$'                 { $o.Resume = $true }
            '^--json$'                   { $o.Json = $true }
            '^--reboot-exit$'            { $o.RebootExit = $true }
            '^(--download-only|--offline)$' { $o.DownloadOnly = $true }
            '^--only$'                   { $i++; $o.Only = [string]$Argv[$i] }
            '^--only='                   { $o.Only = $a -replace '^--only=','' }
            '^--except$'                 { $i++; $o.Except = [string]$Argv[$i] }
            '^--except='                 { $o.Except = $a -replace '^--except=','' }
            '^--metrics$'                { $i++; $o.Metrics = [string]$Argv[$i] }
            '^--metrics='                { $o.Metrics = $a -replace '^--metrics=','' }
            '^--profile$'                { $i++; $o.Profile = [string]$Argv[$i] }
            '^--profile='                { $o.Profile = $a -replace '^--profile=','' }
            '^--changelog$'              { $i++; $o.Changelog = [string]$Argv[$i] }
            '^--changelog='              { $o.Changelog = $a -replace '^--changelog=','' }
            '^--report$'                 { $i++; $o.Report = [string]$Argv[$i] }
            '^--report='                 { $o.Report = $a -replace '^--report=','' }
            default {
                [Console]::Error.WriteLine("Unknown argument: $a (try 'up --help')")
                exit 2
            }
        }
        $i++
    }
    return $o
}

function Args-Prescan-Profile {
    param([string[]]$Argv)
    if (-not $Argv) { return '' }
    for ($i = 0; $i -lt $Argv.Count; $i++) {
        $a = [string]$Argv[$i]
        if ($a -eq '--profile' -and ($i + 1) -lt $Argv.Count) { return [string]$Argv[$i+1] }
        if ($a -match '^--profile=') { return ($a -replace '^--profile=','') }
    }
    return ''
}
