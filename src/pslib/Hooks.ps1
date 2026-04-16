# User hook runner: *.ps1 scripts under hooks/{pre,post}.d/

function Hooks-Run {
    param([string]$Phase)
    $dir = Join-Path $script:EMERGER_CONFIG "hooks\$Phase.d"
    if (-not (Test-Path $dir)) { return }
    $scripts = @(Get-ChildItem $dir -Filter '*.ps1' -ErrorAction SilentlyContinue)
    if ($scripts.Count -eq 0) { return }
    UI-Title "Hooks ($Phase)"
    foreach ($s in $scripts) {
        UI-Sub $s.Name
        if ($script:ArgsGlobal.DryRun) { continue }
        try { & $s.FullName } catch {
            UI-Warn "hook $($s.Name) failed: $($_.Exception.Message)"
            Log-Warn "hook $Phase/$($s.Name) failed"
        }
    }
}
