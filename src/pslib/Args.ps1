# Argument parser. Returns a PSCustomObject with booleans / strings.

# Parse command line $Argv into the options object, onto -Into when given.
# Exit 2 on an unknown argument or a value flag without a value.
function Args-Parse {
    # -Into: start from the object config.ps1 and the profile already set.
    param([string[]]$Argv, $Into = $null)
    if ($Into) { $options = $Into } else { $options = _Args-Defaults }
    # Actions and queries come from the command line only: set in config.ps1
    # or a profile they would run on every run (a self-update among them).
    foreach ($field in @('Help', 'Version', 'SelfUpdate', 'AutoUpdate', 'Errors', 'RebuildCache', 'History',
                         'Doctor', 'ListProfiles', 'Changed', 'Rollback', 'Reboot')) { $options.$field = $false }
    $options.Changelog = ''; $options.Metrics = ''
    if (-not $Argv) { return $options }
    $Argv = _Args-Expand-Bundles $Argv
    $i = 0
    while ($i -lt $Argv.Count) {
        $word = [string]$Argv[$i]
        switch -Regex -CaseSensitive ($word) {
            '^(-h|--help)$'              { $options.Help = $true }
            '^(-V|--version)$'           { $options.Version = $true }
            '^(-n|--dry-run)$'           { $options.DryRun = $true }
            '^(-v|--verbose)$'           { $script:UI_VERBOSE = $true }
            '^(-q|--quiet)$'             { $script:QUIET_LEVEL++ }
            '^-qq$'                      { $script:QUIET_LEVEL = 2 }
            '^-qqq$'                     { $script:QUIET_LEVEL = 3 }
            '^(-y|--yes)$'               { $options.Yes = $true }
            '^--dev$'                    { $options.Dev = $true }
            '^--security$'               { $options.Security = $true }
            '^--firmware$'               { $options.Firmware = $true }
            '^(-nl|--no-logo)$'          { $options.NoLogo = $true }
            '^(-ni|--no-info)$'          { $options.NoInfo = $true }
            '^(-nc|--keep-cache)$'       { $options.KeepCache = $true }
            '^(-nt|--keep-trash)$'       { $options.KeepTrash = $true }
            '^(-err|--errors)$'          { $options.Errors = $true }
            '^--history$'                { $options.History = $true }
            '^--doctor$'                 { $options.Doctor = $true }
            '^(-up|--self-update)$'      { $options.SelfUpdate = $true }
            '^(-au|--auto-update)$'      { $options.AutoUpdate = $true }
            '^(-rc|--rebuild-cache)$'    { $options.RebuildCache = $true }
            '^--snapshot$'               { $options.Snapshot = $true }
            '^--reboot$'                 { $options.Reboot = $true }
            '^--list-profiles$'          { $options.ListProfiles = $true }
            '^--ascii$'                  { $options.Ascii = $true; $script:UI_IS_ASCII = $true; $script:UI_HAS_UNICODE = $false; $script:UI_HAS_EMOJI = $false }
            '^--parallel$'               { $options.Parallel = $true }
            '^--changed$'                { $options.Changed = $true }
            '^--resume$'                 { $options.Resume = $true }
            '^--json$'                   { $options.Json = $true }
            '^(-w|--weather)$'           { $options.Weather = $true }
            '^--reboot-exit$'            { $options.RebootExit = $true }
            '^--download-only$'          { $options.DownloadOnly = $true }
            '^--accept-licenses$'        { $options.AcceptLicenses = $true }
            '^--deep-clean$'             { $options.DeepClean = $true }
            '^--no-firmware$'            { $options.NoFirmware = $true }
            '^--refresh-mirrors$'        { $options.RefreshMirrors = $true }
            '^--rollback$'               { $options.Rollback = $true }
            # End of options: the words after it are ignored.
            '^--$'                       { $i = $Argv.Count }
            '^--(only|except|metrics|profile|changelog)(=|$)' {
                $flag = $Matches[1]
                if ($Matches[2] -eq '=') { $value = $word.Substring($flag.Length + 3) }
                else { $i++; $value = if ($i -lt $Argv.Count) { [string]$Argv[$i] } else { '' } }
                $value = _Args-Need-Value "--$flag" $value
                switch ($flag) {
                    # --except appends to the list from config.ps1 or the profile.
                    'except'    { $options.Except = (@($options.Except, $value) | Where-Object { $_ }) -join ',' }
                    'only'      { $options.Only = $value }
                    'metrics'   { $options.Metrics = $value }
                    # Args-Prescan-Profile already loaded the profile.
                    'profile'   { }
                    'changelog' { $options.Changelog = $value }
                }
            }
            default {
                [Console]::Error.WriteLine("Unknown argument: $word (try `"up --help`")")
                exit 2
            }
        }
        $i++
    }
    return $options
}

# Return every option at its default: the object config.ps1 and the profile
# write into.
function _Args-Defaults {
    return [pscustomobject]@{
        Help=$false; Version=$false
        DryRun=$false; Yes=$false
        Dev=$false; Security=$false; Firmware=$false
        NoLogo=$false; NoInfo=$false; KeepCache=$false; KeepTrash=$false
        Errors=$false; History=$false; Doctor=$false
        SelfUpdate=$false; AutoUpdate=$false; RebuildCache=$false
        Snapshot=$false; Reboot=$false
        Changelog=''
        ListProfiles=$false; Ascii=$false
        Parallel=$false; Changed=$false; Resume=$false
        Json=$false; Weather=$false; RebootExit=$false; DownloadOnly=$false; AcceptLicenses=$false
        DeepClean=$false; NoFirmware=$false; RefreshMirrors=$false; Rollback=$false
        Only=''; Except=''; Metrics=''
    }
}

# Expand short-flag bundles: "-nv" -> "-n -v". A word with a letter outside
# the bundle set, a multi-letter short flag and a long flag stay whole.
function _Args-Expand-Bundles {
    param([string[]]$Argv)
    $allowed = 'hVnvqyw'.ToCharArray()
    $keep = @('-up','-au','-err','-rc','-nl','-ni','-nc','-nt','-qq','-qqq',
              '-h','-V','-n','-v','-q','-y','-w')
    $words = New-Object System.Collections.Generic.List[string]
    foreach ($item in $Argv) {
        $word = [string]$item
        if ($keep -contains $word -or $word.StartsWith('--')) { [void]$words.Add($word); continue }
        if ($word -match '^-[A-Za-z]{2,}$') {
            $letters = $word.Substring(1).ToCharArray()
            $isBundle = $true
            foreach ($letter in $letters) { if ($allowed -notcontains $letter) { $isBundle = $false; break } }
            if ($isBundle) {
                foreach ($letter in $letters) { [void]$words.Add("-$letter") }
                continue
            }
        }
        [void]$words.Add($word)
    }
    return ,$words.ToArray()
}

# Return $Value, or exit 2 with "Missing value for $Flag" when it is empty
# (the flag was the last word, or its value is "").
function _Args-Need-Value {
    param([string]$Flag, [string]$Value)
    if ($Value -ne '') { return $Value }
    [Console]::Error.WriteLine("Missing value for $Flag")
    exit 2
}

# Return the profile named on the command line, the last --profile winning
# as in Args-Parse, so the profile can set defaults before the CLI flags.
function Args-Prescan-Profile {
    param([string[]]$Argv)
    if (-not $Argv) { return '' }
    $name = ''
    for ($i = 0; $i -lt $Argv.Count; $i++) {
        $word = [string]$Argv[$i]
        if ($word -eq '--') { break }
        if ($word -eq '--profile' -and ($i + 1) -lt $Argv.Count) { $name = [string]$Argv[$i+1]; $i++ }
        elseif ($word -match '^--profile=') { $name = ($word -replace '^--profile=','') }
    }
    return $name
}

# Warn about each Unix-only flag set in $script:ArgsGlobal that changes how a
# run goes: Windows ignores it. The Unix-only queries and actions (--changed,
# --changelog, --rollback) exit in the entry point instead.
function Args-Warn-Unsupported {
    $unsupported = [ordered]@{
        Firmware = '--firmware'; NoFirmware = '--no-firmware'; Snapshot = '--snapshot'
        Parallel = '--parallel'; Resume = '--resume'; DownloadOnly = '--download-only'
        DeepClean = '--deep-clean'; RefreshMirrors = '--refresh-mirrors'
    }
    foreach ($field in $unsupported.Keys) {
        if ($script:ArgsGlobal.$field) { UI-Warn "$($unsupported[$field]) is not supported on Windows, ignored." }
    }
}
