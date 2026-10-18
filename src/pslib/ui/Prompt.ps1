# Yes/no prompt of the Windows UI.

# Ask yes/no question $Prompt, $Detail after it, and return $true for yes. -y
# says yes without asking. With no console $Default answers, otherwise it
# answers after EMERGER_PROMPT_TIMEOUT seconds (0 = forever).
function UI-Confirm {
    param([string]$Prompt, [string]$Default = 'n', [string]$Detail)
    if ($script:ArgsGlobal -and $script:ArgsGlobal.Yes) { return $true }
    $isDefaultYes = $Default -match '^[Yy]'
    $hint = if ($isDefaultYes) { 'Y/n' } else { 'y/N' }

    $isInteractive = $true
    try { if ([Console]::IsInputRedirected) { $isInteractive = $false } } catch { $isInteractive = $false }
    if ($isInteractive) { try { $null = [Console]::KeyAvailable } catch { $isInteractive = $false } }
    if (-not $isInteractive) {
        UI-Muted "no terminal for `"$Prompt`", using default ($Default)"
        return $isDefaultYes
    }

    $question = "    " + (UI-Color 'bold magenta' (UI-Glyph ask)) + ' ' + (UI-Color bold $Prompt)
    if ($Detail) { $question += ' ' + (UI-Color 'dim gray' $Detail) }
    $question += ' ' + (UI-Color gray "[$hint]") + ' '
    Write-Host $question -NoNewline

    $timeout = 60
    if ("$env:EMERGER_PROMPT_TIMEOUT" -match '^\d+$') { $timeout = [int]$env:EMERGER_PROMPT_TIMEOUT }
    $answer = ''
    if ($timeout -le 0) {
        $answer = [Console]::ReadLine()
        if ($null -eq $answer) { $answer = '' }
    } else {
        $deadline = [DateTime]::UtcNow.AddSeconds($timeout)
        $typed = New-Object System.Text.StringBuilder
        $isDone = $false
        while (-not $isDone) {
            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq 'Enter') { $isDone = $true; break }
                if ($key.Key -eq 'Backspace') {
                    if ($typed.Length -gt 0) { [void]$typed.Remove($typed.Length - 1, 1); [Console]::Write("`b `b") }
                    continue
                }
                if ([int]$key.KeyChar -ne 0 -and -not [char]::IsControl($key.KeyChar)) {
                    [void]$typed.Append($key.KeyChar); [Console]::Write($key.KeyChar)
                }
                continue
            }
            if ([DateTime]::UtcNow -ge $deadline) {
                Write-Host ''
                UI-Muted "no answer after ${timeout}s, using default ($Default)"
                return $isDefaultYes
            }
            Start-Sleep -Milliseconds 50
        }
        Write-Host ''
        $answer = $typed.ToString()
    }
    $answer = $answer.Trim()
    if (-not $answer) { return $isDefaultYes }
    return ($answer -match '^[Yy]')
}
