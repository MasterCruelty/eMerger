# Windows package manager registry and dispatcher.

# System managers in run order.
$script:PKG_MANAGERS = @(
    'winget','scoop','choco','wsl','PSWindowsUpdate'
)
# Dev toolchains, run after the system managers with --dev.
$script:PKG_DEV = @('rustup','cargo','npm','pnpm','pip','gem')

# Return $true when manager $Manager needs an elevated process.
function Pkg-Need-Admin {
    param([string]$Manager)
    return @('choco','PSWindowsUpdate','wsl') -contains $Manager
}

# Return $true when manager $Manager can install security updates alone, which
# is what --security runs. Only PSWindowsUpdate can, every other manager is skipped.
function Pkg-Has-Security {
    param([string]$Manager)
    return $Manager -eq 'PSWindowsUpdate'
}

# Return $true when manager $Manager is installed (cargo also needs
# cargo-install-update).
function Pkg-Detect {
    param([string]$Manager)
    switch ($Manager) {
        'winget'          { return (Sys-Has winget) }
        'scoop'           { return (Sys-Has scoop) }
        'choco'           { return (Sys-Has choco) }
        'wsl'             { return (Sys-Has wsl) }
        'PSWindowsUpdate' { return [bool](Get-Module -ListAvailable PSWindowsUpdate -ErrorAction SilentlyContinue) }
        'rustup'          { return (Sys-Has rustup) }
        'cargo'           { return (Sys-Has cargo) -and (Sys-Has cargo-install-update) }
        'npm'             { return (Sys-Has npm) }
        'pnpm'            { return (Sys-Has pnpm) }
        'pip'             { return (Sys-Has pip) }
        'gem'             { return (Sys-Has gem) }
        default           { return $false }
    }
}

# Return the detected managers in run order, the dev toolchains too with
# -IncludeDev.
function Pkg-Detect-All {
    param([switch]$IncludeDev)
    $out = @()
    foreach ($manager in $script:PKG_MANAGERS) { if (Pkg-Detect $manager) { $out += $manager } }
    if ($IncludeDev) { foreach ($manager in $script:PKG_DEV) { if (Pkg-Detect $manager) { $out += $manager } } }
    return ,$out
}

# Return the section icon of manager $Manager: an emoji, a Unicode mark or an
# ASCII bullet, as the console allows.
function Pkg-Icon {
    param([string]$Manager)
    if ($script:UI_HAS_EMOJI) {
        $codePoint = switch ($Manager) {
            'winget'          { 0x1F4E6 }
            'scoop'           { 0x1F944 }
            'choco'           { 0x1F36B }
            'wsl'             { 0x1F427 }
            'PSWindowsUpdate' { 0x1FA9F }
            'rustup'          { 0x1F980 }
            'cargo'           { 0x1F980 }
            'npm'             { 0x1F4D7 }
            'pnpm'            { 0x1F4D7 }
            'pip'             { 0x1F40D }
            'gem'             { 0x1F48E }
            default           { 0x2022 }
        }
        return [char]::ConvertFromUtf32($codePoint)
    }
    if ($script:UI_HAS_UNICODE) {
        if (@('winget','msstore','scoop') -contains $Manager) { return [string][char]0x25A3 }
        if ($script:PKG_DEV -contains $Manager)               { return [string][char]0x03BB }
        return [string][char]0x25C6
    }
    return (UI-Glyph bullet)
}

# Return the managers of $Detected this run updates, in order: --only and --except
# applied (case-sensitive) and, under --security, only those with a security
# channel. Each skip is reported.
function Pkg-Select {
    param([string[]]$Detected)
    $onlyNames   = @(); if ($script:ArgsGlobal.Only)   { $onlyNames   = $script:ArgsGlobal.Only -split ',' | ForEach-Object { $_.Trim() } }
    $exceptNames = @(); if ($script:ArgsGlobal.Except) { $exceptNames = $script:ArgsGlobal.Except -split ',' | ForEach-Object { $_.Trim() } }

    $filtered = @()
    foreach ($manager in $Detected) {
        if ($onlyNames.Count   -gt 0 -and ($onlyNames -cnotcontains $manager))  { continue }
        if ($exceptNames.Count -gt 0 -and ($exceptNames -ccontains $manager))   { UI-Muted "skip $manager (--except)"; continue }
        if ($script:ArgsGlobal.Security -and -not (Pkg-Has-Security $manager)) {
            UI-Warn "skip ${manager}: no security-only updates, --security never runs a full upgrade"
            Log-Warn "$manager skipped: no security channel"
            continue
        }
        $filtered += $manager
    }
    return ,$filtered
}

# Count the installed choco packages, the total for "choco upgrade all".
function _Pkg-Choco-Count {
    $root = $env:ChocolateyInstall
    if (-not $root -and $env:ProgramData) { $root = Join-Path $env:ProgramData 'chocolatey' }
    if (-not $root) { return 0 }
    $lib = Join-Path $root 'lib'
    if (-not (Test-Path $lib)) { return 0 }
    return @(Get-ChildItem $lib -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch '\.(lock|bkp)$|^\.' }).Count
}

# Run Windows Update through PSWindowsUpdate, security updates alone under
# --security. Installs and accepts each update's EULA only with
# --accept-licenses, otherwise lists them. Return $true on success.
function _Pkg-Run-WindowsUpdate {
    # Child process runs the block, so build it as text.
    $label = 'Windows Update'
    $category = ''
    if ($script:ArgsGlobal.Security) { $label = 'Windows Update (security)'; $category = " -Category 'Security Updates'" }
    # -AcceptAll accepts each update's EULA: only on request, else list.
    $install = ''
    if ($script:ArgsGlobal.AcceptLicenses) { $install = ' -AcceptAll -Install -IgnoreReboot' }
    $updateBlock = [scriptblock]::Create(
        "Import-Module PSWindowsUpdate -ErrorAction Stop`n" +
        "`$errorsBefore = `$Error.Count`n" +
        "Get-WindowsUpdate$install -Confirm:`$false -Verbose$category`n" +
        # Failed updates are non-terminating errors, the exit code stays 0.
        "if (`$Error.Count -gt `$errorsBefore) { `$global:LASTEXITCODE = 1 }")
    $isOk = Run-Cmd $label $updateBlock
    if (-not $script:ArgsGlobal.AcceptLicenses) {
        UI-Muted 'updates not installed: they may need licence agreement, run with --accept-licenses'
    }
    return $isOk
}

# Upgrade each outdated pip package for the user, in a child PowerShell. A
# failing package fails the step without stopping the others.
function _Pkg-Run-Pip {
    return (Run-Cmd 'pip upgrade outdated' {
        $raw = (pip list --outdated --format=json 2>$null) -join ''
        $outdated = @()
        if ($raw) { $outdated = @($raw | ConvertFrom-Json) }
        if ($outdated.Count -eq 0) { 'nothing to upgrade'; return }
        $i = 0; $failCount = 0
        foreach ($package in $outdated) {
            $i++
            "[$i/$($outdated.Count)] $($package.name)"
            pip install --user -U $package.name 2>&1 | ForEach-Object { "$_" }
            if ($LASTEXITCODE -ne 0) { $failCount++ }
        }
        $global:LASTEXITCODE = [int]($failCount -gt 0)
    })
}

# Packages changed so far in this run, for the summary.
$script:PKG_CHANGED = 0

# Run every step of manager $Manager under its section header and log the
# result. Return $true when all steps succeeded.
function Pkg-Run {
    param([string]$Manager)
    $script:PKG_CURRENT = $Manager
    UI-Section (Pkg-Icon $Manager) $Manager (Estimate-Read $Manager)
    Log-Info "starting $Manager"
    $isOk = $true
    switch ($Manager) {
        'winget' {
            $isOk = (Run-Cmd 'winget source update' -Exe winget -ArgList @('source','update','--disable-interactivity') -AnyExit) -and $isOk
            # Upgrading can mean agreeing to package and source licences: only on request.
            if ($script:ArgsGlobal.AcceptLicenses) {
                # 0x8A15002B: no applicable upgrade.
                $isOk = (Run-Cmd 'winget upgrade --all' -Exe winget -OkCodes @(-1978335189) -ArgList @(
                    'upgrade','--all','--include-unknown','--accept-package-agreements',
                    '--accept-source-agreements','--silent','--disable-interactivity')) -and $isOk
            } else {
                $isOk = (Run-Cmd 'winget upgrade' -Exe winget -AnyExit -ArgList @('upgrade','--include-unknown','--disable-interactivity')) -and $isOk
                UI-Muted 'upgrades not installed: they may need licence agreement, run with --accept-licenses'
            }
        }
        'scoop' {
            $isOk = (Run-Cmd 'scoop update'      -Exe scoop -ArgList @('update')) -and $isOk
            $isOk = (Run-Cmd 'scoop update *'    -Exe scoop -ArgList @('update','*')) -and $isOk
            $isOk = (Run-Cmd 'scoop cleanup *'   -Exe scoop -ArgList @('cleanup','*')) -and $isOk
            $isOk = (Run-Cmd 'scoop cache rm *'  -Exe scoop -ArgList @('cache','rm','*')) -and $isOk
        }
        'choco' {
            # -y accepts package licences: upgrade only on request. No --limit-output,
            # it hides the lines the progress parser counts.
            if ($script:ArgsGlobal.AcceptLicenses) {
                $isOk = (Run-Cmd 'choco upgrade all' -Exe choco -ArgList @('upgrade','all','-y') -Total (_Pkg-Choco-Count)) -and $isOk
            } else {
                # Exit code 2: outdated packages found.
                $isOk = (Run-Cmd 'choco outdated' -Exe choco -OkCodes @(2) -ArgList @('outdated')) -and $isOk
                UI-Muted 'upgrades not installed: they may need licence agreement, run with --accept-licenses'
            }
        }
        'wsl' {
            $isOk = (Run-Cmd 'wsl --update'      -Exe wsl -ArgList @('--update')) -and $isOk
        }
        'PSWindowsUpdate' { $isOk = (_Pkg-Run-WindowsUpdate) -and $isOk }
        'rustup' { $isOk = (Run-Cmd 'rustup update'            -Exe rustup -ArgList @('update')) -and $isOk }
        'cargo'  { $isOk = (Run-Cmd 'cargo install-update -a' -Exe cargo  -ArgList @('install-update','-a')) -and $isOk }
        'npm'    { $isOk = (Run-Cmd 'npm -g update'           -Exe npm    -ArgList @('update','-g')) -and $isOk }
        'pnpm'   { $isOk = (Run-Cmd 'pnpm -g update'          -Exe pnpm   -ArgList @('-g','update')) -and $isOk }
        'pip'    { $isOk = (_Pkg-Run-Pip) -and $isOk }
        'gem'    { $isOk = (Run-Cmd 'gem update'              -Exe gem    -ArgList @('update')) -and $isOk }
    }
    $script:PKG_CURRENT = ''
    if ($isOk) { Log-Info "$Manager ok" } else { Log-Error "$Manager failed" }
    return $isOk
}
