# User hook runner: *.ps1 scripts under hooks/{pre,post}.d/

# Run each *.ps1 hook of $Phase (pre or post) in name order. A failing hook is a
# warning and the next one runs. Under --dry-run hooks are listed only.
function Hooks-Run {
    param([string]$Phase)
    $dir = Join-Path $script:EMERGER_CONFIG "hooks\$Phase.d"
    if (-not (Test-Path -LiteralPath $dir)) { return }
    $scripts = @(Get-ChildItem -LiteralPath $dir -Filter '*.ps1' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($scripts.Count -eq 0) { return }
    UI-Title "Hooks ($Phase)"
    foreach ($hook in $scripts) {
        UI-Sub $hook.Name
        if ($script:ArgsGlobal.DryRun) { continue }
        $global:LASTEXITCODE = 0
        try {
            # Under --json stdout carries the JSON object alone.
            if ($script:ArgsGlobal.Json) { & $hook.FullName *>&1 | ForEach-Object { [Console]::Error.WriteLine("$_") } }
            else { & $hook.FullName }
        } catch {
            UI-Warn "hook $($hook.Name) failed: $($_.Exception.Message)"
            Log-Warn "hook $Phase/$($hook.Name) failed"
            continue
        }
        # `exit N` in a hook, or its last native command, sets the code.
        if ($global:LASTEXITCODE -ne 0) {
            UI-Warn "hook $($hook.Name) failed (exit $global:LASTEXITCODE)"
            Log-Warn "hook $Phase/$($hook.Name) failed"
        }
    }
}
