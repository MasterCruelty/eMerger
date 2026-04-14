# Windows package manager registry and dispatcher.

$script:PKG_MANAGERS = @(
    'winget','scoop','choco','wsl','PSWindowsUpdate'
)
$script:PKG_DEV = @('rustup','cargo','npm','pnpm','pip','gem')

function Pkg-Need-Admin {
    param([string]$M)
    return @('choco','PSWindowsUpdate','wsl') -contains $M
}

function Pkg-Detect {
    param([string]$M)
    switch ($M) {
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

function Pkg-Detect-All {
    param([switch]$IncludeDev)
    $out = @()
    foreach ($m in $script:PKG_MANAGERS) { if (Pkg-Detect $m) { $out += $m } }
    if ($IncludeDev) { foreach ($m in $script:PKG_DEV) { if (Pkg-Detect $m) { $out += $m } } }
    return ,$out
}

function Pkg-Need-Admin-Any {
    param([switch]$IncludeDev)
    $detected = Pkg-Detect-All -IncludeDev:$IncludeDev
    foreach ($m in $detected) { if (Pkg-Need-Admin $m) { return $true } }
    return $false
}

function Pkg-Icon {
    param([string]$M)
    if (-not $script:UI_UNICODE) { return '*' }
    switch ($M) {
        'winget'          { '📦' }
        'scoop'           { '🥄' }
        'choco'           { '🍫' }
        'wsl'             { '🐧' }
        'PSWindowsUpdate' { '🪟' }
        'rustup'          { '🦀' }
        'cargo'           { '🦀' }
        'npm'             { '📗' }
        'pnpm'            { '📗' }
        'pip'             { '🐍' }
        'gem'             { '💎' }
        default           { '*' }
    }
}

function Run-Cmd {
    param([string]$Label, [scriptblock]$Block)
    if ($script:ArgsGlobal.DryRun) {
        UI-Sub "[dry-run] $Label"
        return $true
    }
    if ($script:UI_VERBOSE) {
        UI-Sub $Label
        try { & $Block } catch { UI-Fail $Label 1; Log-Error "$Label : $_"; return $false }
        if ($LASTEXITCODE -and $LASTEXITCODE -ne 0) { UI-Fail $Label $LASTEXITCODE; Log-Error "$Label rc=$LASTEXITCODE"; return $false }
        UI-Done $Label
        return $true
    }
    $tmp = [IO.Path]::GetTempFileName()
    try {
        & $Block *>$tmp
        $rc = $LASTEXITCODE
        if (-not $rc) { $rc = 0 }
    } catch {
        $rc = 1
        $_ | Out-File $tmp -Append
    }
    if ($rc -ne 0) {
        UI-Fail $Label $rc
        Log-Error "$Label rc=$rc"
        Get-Content $tmp -Tail 15 -ErrorAction SilentlyContinue | ForEach-Object {
            [Console]::Error.WriteLine("    $_")
        }
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        return $false
    }
    UI-Done $Label
    Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    return $true
}

function Pkg-Run {
    param([string]$M)
    $script:PKG_CURRENT = $M
    $icon = Pkg-Icon $M
    UI-Title "$icon $M"
    Log-Info "starting $M"
    $ok = $true
    switch ($M) {
        'winget' {
            $ok = (Run-Cmd 'winget source update' { winget source update --disable-interactivity *>$null; $global:LASTEXITCODE = 0 }) -and $ok
            $ok = (Run-Cmd 'winget upgrade --all' {
                winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --silent --disable-interactivity
                if (-not $LASTEXITCODE) { $global:LASTEXITCODE = 0 }
            }) -and $ok
        }
        'scoop' {
            $ok = (Run-Cmd 'scoop update'      { scoop update }) -and $ok
            $ok = (Run-Cmd 'scoop update *'    { scoop update * }) -and $ok
            $ok = (Run-Cmd 'scoop cleanup *'   { scoop cleanup * }) -and $ok
            $ok = (Run-Cmd 'scoop cache rm *'  { scoop cache rm * }) -and $ok
        }
        'choco' {
            $ok = (Run-Cmd 'choco upgrade all' { choco upgrade all -y --limit-output }) -and $ok
        }
        'wsl' {
            $ok = (Run-Cmd 'wsl --update'      { wsl --update }) -and $ok
        }
        'PSWindowsUpdate' {
            $ok = (Run-Cmd 'Windows Update' {
                Import-Module PSWindowsUpdate -ErrorAction Stop
                Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot -Confirm:$false
            }) -and $ok
        }
        'rustup' { $ok = (Run-Cmd 'rustup update'            { rustup update }) -and $ok }
        'cargo'  { $ok = (Run-Cmd 'cargo install-update -a' { cargo install-update -a }) -and $ok }
        'npm'    { $ok = (Run-Cmd 'npm -g update'           { npm update -g }) -and $ok }
        'pnpm'   { $ok = (Run-Cmd 'pnpm -g update'          { pnpm -g update }) -and $ok }
        'pip'    { $ok = (Run-Cmd 'pip upgrade outdated' {
            pip list --outdated --format=json 2>$null |
                ConvertFrom-Json |
                ForEach-Object { pip install --user -U $_.name 2>$null }
        }) -and $ok }
        'gem'    { $ok = (Run-Cmd 'gem update'              { gem update }) -and $ok }
    }
    $script:PKG_CURRENT = ''
    if ($ok) { Log-Info "$M ok" } else { Log-Error "$M failed" }
    return $ok
}
