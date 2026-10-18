# Run one manager step: command resolution, child process, live monitor,
# timeout and retry.

# Quote $Argument for a Windows command line (CommandLineToArgvW rules).
function Run-Quote {
    param([string]$Argument)
    if ($Argument -and $Argument -notmatch '[\s"]') { return $Argument }
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

# Escape a command line for cmd.exe: outside quotes caret-escape & | ^ < > %,
# inside quotes (where a caret is literal) step out to escape % as "^%".
function _Run-Escape-CmdExe {
    param([string]$Line)
    $builder = New-Object System.Text.StringBuilder
    $isInQuotes = $false
    foreach ($char in $Line.ToCharArray()) {
        if ($char -eq '"') { $isInQuotes = -not $isInQuotes; [void]$builder.Append($char); continue }
        if ($isInQuotes) {
            if ($char -eq '%') { [void]$builder.Append('"^%"') } else { [void]$builder.Append($char) }
            continue
        }
        if ('&|^<>%'.IndexOf($char) -ge 0) { [void]$builder.Append('^') }
        [void]$builder.Append($char)
    }
    return $builder.ToString()
}

# Return the path of the running edition's console host in $PSHOME (pwsh or
# powershell), not the process image, which is powershell_ise.exe under the ISE.
function Run-PowerShell-Path {
    $name = if ($PSVersionTable.PSEdition -eq 'Core') { 'pwsh' } else { 'powershell' }
    foreach ($leaf in @("$name.exe", $name)) {
        $exe = Join-Path $PSHOME $leaf
        if (Test-Path -LiteralPath $exe -PathType Leaf) { return $exe }
    }
    return "$name.exe"
}

# Return the arguments of a child PowerShell running $Body, which exits with
# the last native exit code, or 1 on a terminating error.
function _Run-PowerShell-Args {
    param([string]$Body)
    $script = @"
`$ProgressPreference = 'SilentlyContinue'
`$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding `$false } catch {}
`$global:LASTEXITCODE = 0
try { & { $Body } } catch { [Console]::Error.WriteLine("ERROR: " + `$_); exit 1 }
exit [int]`$global:LASTEXITCODE
"@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($script))
    return "-NoProfile -NonInteractive -ExecutionPolicy Bypass -OutputFormat Text -EncodedCommand $encoded"
}

# Resolve $Exe with $ArgList, or $Block, to the {File, Args} to start: an .exe
# directly, a .cmd or .bat through cmd.exe, a .ps1 shim (scoop, npm) and a
# script block through a child PowerShell.
function _Run-Resolve {
    param([string]$Exe, [string[]]$ArgList, [scriptblock]$Block)
    if ($Block) { return @{ File = (Run-PowerShell-Path); Args = (_Run-PowerShell-Args $Block.ToString()) } }
    $joined = ($ArgList | ForEach-Object { Run-Quote $_ }) -join ' '
    $app = Get-Command $Exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($app) {
        $path = $app.Source
        if (-not $path) { $path = $app.Path }
        if ($path -match '\.(cmd|bat)$') {
            $comSpec = $env:ComSpec
            if (-not $comSpec) { $comSpec = 'cmd.exe' }
            return @{ File = $comSpec; Args = "/d /s /c `"$(_Run-Escape-CmdExe "$(Run-Quote $path) $joined")`"" }
        }
        return @{ File = $path; Args = $joined }
    }
    $shim = Get-Command $Exe -CommandType ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($shim) {
        $quoted = ($ArgList | ForEach-Object { "'" + ($_ -replace "'", "''") + "'" }) -join ' '
        return @{ File = (Run-PowerShell-Path); Args = (_Run-PowerShell-Args "& '$($shim.Source -replace "'", "''")' $quoted") }
    }
    return @{ File = $Exe; Args = $joined }
}

# Longest line, in characters, that reaches the progress parsers and the
# monitor: a longer one is cut, so one unterminated feed cannot grow the carry
# or make a parser scan more than this.
$script:RUN_MAX_LINE = 1024

# Append output $Chunk to $State.Log and feed its complete lines (CR or LF),
# sanitised and cut to RUN_MAX_LINE, to the progress parser and the monitor,
# the rest kept (cut the same way) in $State.Carry.
function _Run-Consume {
    param($State, [string]$Chunk)
    if ($Chunk.IndexOf([char]0) -ge 0) { $Chunk = $Chunk.Replace([string][char]0, '') }  # UTF-16 from old wsl.exe
    [void]$State.Log.Append($Chunk)
    if ($State.Log.Length -gt 2MB) { [void]$State.Log.Remove(0, $State.Log.Length - 1MB) }
    $parts = [regex]::Split($State.Carry + $Chunk, '\r\n|\r|\n')
    $State.Carry = $parts[$parts.Count - 1]
    if ($State.Carry.Length -gt $script:RUN_MAX_LINE) { $State.Carry = $State.Carry.Substring(0, $script:RUN_MAX_LINE) }
    for ($i = 0; $i -lt $parts.Count - 1; $i++) {
        $segment = $parts[$i]
        if ($segment.Length -gt $script:RUN_MAX_LINE) { $segment = $segment.Substring(0, $script:RUN_MAX_LINE) }
        $segment = UI-Sanitize $segment
        if (-not $segment.Trim()) { continue }
        # Parser errors must never reach _Run-Process, whose finally kills the child.
        $message = ''
        try { $message = Progress-Feed $segment } catch { $message = '' }
        if ($message -eq ' ') { continue }
        if ($message) { UI-Monitor-Text $message } else { UI-Monitor-Text $segment }
    }
}

# Kill $Process and every process it started. Kill($true) needs .NET Core 3
# or later, 5.1 falls back to taskkill /T, then to a plain Kill().
function _Run-Kill-Tree {
    param([Diagnostics.Process]$Process)
    try { if ($Process.HasExited) { return } } catch { return }
    try { $Process.Kill($true); return } catch {}
    try { & taskkill.exe /PID $Process.Id /T /F 2>&1 | Out-Null; if ($Process.WaitForExit(2000)) { return } } catch {}
    try { $Process.Kill() } catch {}
}

# Return the deadline of one step from $script:MANAGER_TIMEOUT seconds, or
# $null when it is 0 or unset (no timeout).
function _Run-Deadline {
    $seconds = 0
    if ("$($script:MANAGER_TIMEOUT)" -match '^\d{1,9}$') { $seconds = [int]$script:MANAGER_TIMEOUT }
    if ($seconds -le 0) { return $null }
    return [DateTime]::UtcNow.AddSeconds($seconds)
}

# Exit code reported for a step killed by MANAGER_TIMEOUT, as the timeout command does.
$script:RUN_TIMEOUT_RC = 124

# Build the start info of resolved target $Target ({File, Args}), run without
# the shell.
function _Run-New-StartInfo {
    param([hashtable]$Target)
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = $Target.File
    $startInfo.Arguments = $Target.Args
    $startInfo.UseShellExecute = $false
    return $startInfo
}

# Run resolved target $Target, its stdout and stderr read asynchronously into
# $State and the monitor redrawn in between (no threads or events, so 5.1 and
# 7 behave the same). Return the exit code, or RUN_TIMEOUT_RC with
# $State.HasTimedOut set when MANAGER_TIMEOUT expired.
function _Run-Process {
    param([hashtable]$Target, $State)
    $startInfo = _Run-New-StartInfo $Target
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.RedirectStandardInput = $true
    $startInfo.CreateNoWindow = $false
    $encoding = New-Object System.Text.UTF8Encoding $false
    $startInfo.StandardOutputEncoding = $encoding
    $startInfo.StandardErrorEncoding = $encoding
    $startInfo.EnvironmentVariables['WSL_UTF8'] = '1'
    $startInfo.EnvironmentVariables['PYTHONIOENCODING'] = 'utf-8'

    $process = [Diagnostics.Process]::Start($startInfo)
    $isFinished = $false
    try {
        try { $process.StandardInput.Close() } catch {}
        $outBuffer = New-Object char[] 8192
        $errBuffer = New-Object char[] 8192
        $outRead = $process.StandardOutput.ReadAsync($outBuffer, 0, $outBuffer.Length)
        $errRead = $process.StandardError.ReadAsync($errBuffer, 0, $errBuffer.Length)
        $next = [DateTime]::UtcNow
        $deadline = _Run-Deadline
        while ($outRead -or $errRead) {
            if ($deadline -and [DateTime]::UtcNow -ge $deadline) {
                _Run-Kill-Tree $process
                $State.HasTimedOut = $true
                [void]$State.Log.AppendLine("timed out after $($script:MANAGER_TIMEOUT)s (MANAGER_TIMEOUT), process tree killed")
                [void]$process.WaitForExit(5000)
                $isFinished = $true
                return $script:RUN_TIMEOUT_RC
            }
            $pending = @()
            if ($outRead) { $pending += $outRead }
            if ($errRead) { $pending += $errRead }
            $wait = [int][math]::Max(0, ($next - [DateTime]::UtcNow).TotalMilliseconds)
            if ($deadline) { $wait = [int][math]::Min([double]$wait, [math]::Max(0.0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)) }
            [void][Threading.Tasks.Task]::WaitAny([Threading.Tasks.Task[]]$pending, $wait)
            if ($outRead -and $outRead.IsCompleted) {
                $count = $outRead.Result
                if ($count -gt 0) { _Run-Consume $State ([string]::new($outBuffer, 0, $count)); $outRead = $process.StandardOutput.ReadAsync($outBuffer, 0, $outBuffer.Length) }
                else { $outRead = $null }
            }
            if ($errRead -and $errRead.IsCompleted) {
                $count = $errRead.Result
                if ($count -gt 0) { _Run-Consume $State ([string]::new($errBuffer, 0, $count)); $errRead = $process.StandardError.ReadAsync($errBuffer, 0, $errBuffer.Length) }
                else { $errRead = $null }
            }
            if ([DateTime]::UtcNow -ge $next) {
                UI-Monitor-Frame
                $next = [DateTime]::UtcNow.AddMilliseconds(100)
            }
        }
        if ($State.Carry) { _Run-Consume $State "`n" }
        $process.WaitForExit()
        $isFinished = $true
        return $process.ExitCode
    } finally {
        # Ctrl-C: don't leave the child or anything it started running.
        if (-not $isFinished) {
            _Run-Kill-Tree $process
            UI-Monitor-Stop
        }
        $process.Dispose()
    }
}

# Show verbose output lines from the pipeline: on the host, or on stderr
# under --json, where stdout carries the JSON object alone.
function _Run-Show {
    process {
        if ($script:ArgsGlobal.Json) { [Console]::Error.WriteLine("$_") } else { $_ | Out-Host }
    }
}

# Run a resolved target with the console inherited (verbose mode) under the
# MANAGER_TIMEOUT deadline, its stdout copied to stderr under --json. Return
# its exit code, or RUN_TIMEOUT_RC after killing the process tree.
function _Run-Inline {
    param([hashtable]$Target)
    $startInfo = _Run-New-StartInfo $Target
    $isToStderr = [bool]$script:ArgsGlobal.Json
    $startInfo.RedirectStandardOutput = $isToStderr
    $process = [Diagnostics.Process]::Start($startInfo)
    $copy = $null
    if ($isToStderr) { $copy = $process.StandardOutput.BaseStream.CopyToAsync([Console]::OpenStandardError()) }
    try {
        $deadline = _Run-Deadline
        # WaitForExit takes an int of milliseconds: wait in slices that fit.
        while (-not $process.WaitForExit([int][math]::Min([double][int]::MaxValue, [math]::Max(0.0, ($deadline - [DateTime]::UtcNow).TotalMilliseconds)))) {
            if ([DateTime]::UtcNow -lt $deadline) { continue }
            _Run-Kill-Tree $process
            [void]$process.WaitForExit(5000)
            return $script:RUN_TIMEOUT_RC
        }
        $process.WaitForExit()
        return $process.ExitCode
    } finally {
        if (-not $process.HasExited) { _Run-Kill-Tree $process }
        if ($copy) { try { [void]$copy.Wait(2000) } catch {} }
        $process.Dispose()
    }
}

# Return $true when step output $Text shows a transient network failure,
# matched against the retry patterns.
function _Run-Is-Transient {
    param([string]$Text)
    return $Text -match '(Temporary failure|Could not resolve|Connection (timed out|reset|refused)|network is unreachable|503 |502 |504 |failed to fetch|EOF occurred|timed out|Try again later|0x80072EE2|0x80072EFD)'
}

# Steps of the current manager, recorded when set (the elevated child sends
# them to the caller, which replays them).
$script:RUN_STEPS = $null

# Record one finished step in RUN_STEPS when recording is on.
function _Run-Record {
    param([string]$Label, [bool]$IsOk, [string]$Rc = '0', [string]$Stat = '', [string[]]$Tail = @())
    if ($null -eq $script:RUN_STEPS) { return }
    $script:RUN_STEPS.Add([pscustomobject]@{ label = $Label; ok = $IsOk; rc = $Rc; stat = $Stat; tail = @($Tail) })
}

# Run one step under the live monitor, either -Exe/-ArgList or a script
# block (in a child PowerShell). -OkCodes: more exit codes that mean
# success. -AnyExit: ignore the exit code.
function Run-Cmd {
    param(
        [Parameter(Position = 0)][string]$Label,
        [Parameter(Position = 1)][scriptblock]$Block,
        [string]$Exe,
        [string[]]$ArgList = @(),
        [int[]]$OkCodes = @(),
        [switch]$AnyExit,
        [int]$Total = 0,
        [string]$Parser
    )
    if (-not $Parser) { $Parser = $script:PKG_CURRENT }
    $shown = if ($Exe) { (@($Exe) + $ArgList) -join ' ' } else { $Label }
    if ($script:ArgsGlobal.DryRun) {
        UI-Sub "[dry-run] $shown"
        return $true
    }
    if ($script:UI_VERBOSE) {
        return (_Run-Cmd-Verbose -Label $Label -Block $Block -Exe $Exe -ArgList $ArgList -OkCodes $OkCodes -AnyExit:$AnyExit)
    }
    return (_Run-Cmd-Monitored -Label $Label -Block $Block -Exe $Exe -ArgList $ArgList -OkCodes $OkCodes -AnyExit:$AnyExit `
                -Total $Total -Parser $Parser)
}

# Verbose path of Run-Cmd: output on the console, no monitor and no retry.
# Return $true on success.
function _Run-Cmd-Verbose {
    param([string]$Label, [scriptblock]$Block, [string]$Exe, [string[]]$ArgList, [int[]]$OkCodes, [switch]$AnyExit)
    UI-Sub $Label
    # In-process native calls: stderr and exit codes are judged by $rc,
    # never raised as errors (5.1 turns redirected stderr into one under Stop).
    $ErrorActionPreference = 'Continue'
    $PSNativeCommandUseErrorActionPreference = $false
    $rc = 0
    try {
        $global:LASTEXITCODE = 0
        if (_Run-Deadline) {
            # Child process, so MANAGER_TIMEOUT can stop it, on the same console.
            $rc = _Run-Inline (_Run-Resolve $Exe $ArgList $Block)
            if ($rc -eq $script:RUN_TIMEOUT_RC) { UI-Err "${Label}: timed out after $($script:MANAGER_TIMEOUT)s (MANAGER_TIMEOUT), process tree killed" }
        } else {
            # _Run-Show, or the output ends up in this function's return value.
            if ($Exe) { & $Exe @ArgList | _Run-Show } else { & $Block *>&1 | _Run-Show }
            $rc = [int]$global:LASTEXITCODE
        }
    } catch { UI-Err "$_"; $rc = 1 }
    if ($rc -eq 0 -or $AnyExit -or $OkCodes -contains $rc) { UI-Done $Label; _Run-Record $Label $true; return $true }
    UI-Fail $Label $rc
    Log-Error "$Label rc=$rc"
    _Run-Record $Label $false "$rc"
    return $false
}

# Monitored path of Run-Cmd: output parsed under the live monitor, a transient
# failure retried up to RETRY_ATTEMPTS times. Return $true on success.
function _Run-Cmd-Monitored {
    param([string]$Label, [scriptblock]$Block, [string]$Exe, [string[]]$ArgList, [int[]]$OkCodes, [switch]$AnyExit,
          [int]$Total, [string]$Parser)
    $attempt = 1
    while ($true) {
        Progress-Reset $Parser $Total
        $state = @{ Log = (New-Object System.Text.StringBuilder); Carry = ''; HasTimedOut = $false }
        UI-Monitor-Start $Label
        $rc = 0
        try {
            $rc = _Run-Process (_Run-Resolve $Exe $ArgList $Block) $state
        } catch {
            [void]$state.Log.AppendLine("$_")
            $rc = 1
        }
        UI-Monitor-Stop

        if ($rc -eq 0 -or $AnyExit -or $OkCodes -contains $rc) {
            $script:PKG_CHANGED += (Progress-Changed)
            $stat = Progress-Summarize
            UI-Done $Label $stat
            _Run-Record $Label $true '0' $stat
            return $true
        }
        # Timeouts are final: retrying a stalled step only doubles the wait.
        if (-not $state.HasTimedOut -and (_Run-Is-Transient $state.Log.ToString()) -and $attempt -lt $script:RETRY_ATTEMPTS) {
            UI-Warn "${Label}: transient failure, retrying ($attempt/$($script:RETRY_ATTEMPTS))"
            Log-Warn "${Label}: retry $attempt (rc=$rc)"
            Start-Sleep -Seconds ($script:RETRY_DELAY * $attempt)
            $attempt++
            continue
        }
        break
    }
    $script:PKG_CHANGED += (Progress-Changed)
    UI-Fail $Label $rc
    Log-Error "$Label rc=$rc"
    # Keep only what's left after the last CR, like the terminal shows it.
    $lines = @(($state.Log.ToString() -split '\r?\n') | ForEach-Object { UI-Sanitize (($_ -split '\r')[-1]) } | Where-Object { $_.Trim() })
    $tail = @($lines | Select-Object -Last 20)
    UI-Fail-Tail $tail
    Log-Error (($lines | Select-Object -Last 50) -join "`n")
    _Run-Record $Label $false "$rc" '' $tail
    return $false
}
