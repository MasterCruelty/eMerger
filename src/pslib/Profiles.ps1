# Profiles: named *.ps1 files that preset $script:ArgsGlobal defaults.
# Search:
#   1) $EMERGER_CONFIG\profiles.d\<name>.ps1  (user)
#   2) $EMERGER_ROOT\share\profiles\<name>.ps1 (shipped)

# Dot-source profile $Name from the user's profiles.d, else the shipped
# ones. Exit 2 for an invalid name or a profile that does not exist.
function Profiles-Load {
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
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            . $candidate
            Log-Info "profile loaded: $Name ($candidate)"
            return
        }
    }
    [Console]::Error.WriteLine("Profile '$Name' not found. Looked in:")
    $candidates | ForEach-Object { [Console]::Error.WriteLine("  $_") }
    exit 2
}

# Print every profile with its description in name order, a user profile
# hiding a shipped one of the same name (--list-profiles).
function Profiles-List {
    UI-Title 'Available profiles'
    $seen = @{}
    foreach ($dir in @((Join-Path $script:EMERGER_CONFIG 'profiles.d'),
                     (Join-Path $script:EMERGER_ROOT 'share\profiles'))) {
        if (-not (Test-Path -LiteralPath $dir)) { continue }
        Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name | ForEach-Object {
            $name = $_.BaseName
            if ($seen.ContainsKey($name)) { return }
            $seen[$name] = $true
            $descLine = Select-String -Path $_.FullName -Pattern '^# description:' -ErrorAction SilentlyContinue | Select-Object -First 1
            $description = ''
            if ($descLine) { $description = $descLine.Line -replace '^# description:\s*','' }
            Write-Host "  $(UI-Color cyan $name)  $(UI-Color gray $description)"
        }
    }
}
