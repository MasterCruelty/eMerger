# Profiles: named *.ps1 files that preset $script:ArgsGlobal defaults.
# Search:
#   1) $EMERGER_CONFIG\profiles.d\<name>.ps1  (user)
#   2) $EMERGER_ROOT\share\profiles\<name>.ps1 (shipped)

function Load-Profile {
    param([string]$Name)
    if (-not $Name) { return }
    if ($Name -notmatch '^[A-Za-z0-9._-]+$') {
        [Console]::Error.WriteLine("Invalid profile name: '$Name' (allowed: letters, digits, dot, dash, underscore)")
        exit 2
    }
    $candidates = @(
        (Join-Path $script:EMERGER_CONFIG "profiles.d\$Name.ps1"),
        (Join-Path $script:EMERGER_ROOT   "share\profiles\$Name.ps1")
    )
    foreach ($f in $candidates) {
        if (Test-Path -LiteralPath $f) {
            . $f
            Log-Info "profile loaded: $Name ($f)"
            return
        }
    }
    [Console]::Error.WriteLine("Profile '$Name' not found. Looked in:")
    $candidates | ForEach-Object { [Console]::Error.WriteLine("  $_") }
    exit 2
}

function List-Profiles {
    UI-Title 'Available profiles'
    $seen = @{}
    foreach ($d in @((Join-Path $script:EMERGER_CONFIG 'profiles.d'),
                     (Join-Path $script:EMERGER_ROOT 'share\profiles'))) {
        if (-not (Test-Path $d)) { continue }
        Get-ChildItem $d -Filter '*.ps1' -ErrorAction SilentlyContinue | ForEach-Object {
            $n = $_.BaseName
            if ($seen.ContainsKey($n)) { return }
            $seen[$n] = $true
            $descLine = Select-String -Path $_.FullName -Pattern '^# description:' -ErrorAction SilentlyContinue | Select-Object -First 1
            $desc = ''
            if ($descLine) { $desc = $descLine.Line -replace '^# description:\s*','' }
            Write-Host "  $(UI-Color cyan $n)  $(UI-Color gray $desc)"
        }
    }
}
