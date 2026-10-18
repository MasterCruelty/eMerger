#!/usr/bin/env bats
# PowerShell temp folder cleaning, run through pwsh where it is installed.

load ps_helper

@test "ps: temp cleanup removes a directory link without touching or counting its target" {
    export TEMP="$HOME/tmp" SystemRoot="$HOME/Windows"
    mkdir -p "$TEMP/sub/deep" "$HOME/victim" "$SystemRoot"
    head -c 1048576 /dev/zero >"$TEMP/sub/deep/junk"
    head -c 4194304 /dev/zero >"$HOME/victim/keep"
    ln -s "$HOME/victim" "$TEMP/link"
    ln -s "$HOME/victim" "$TEMP/sub/deep/inner"
    run ps '. (Join-Path $env:PSLIB "clean/Size.ps1"); . (Join-Path $env:PSLIB "clean/Temp.ps1")
        "size=$(_Temp-Folder-Size-KB $env:TEMP)"
        $script:ArgsGlobal.Yes = $true
        Clean-Temp'
    [ "$status" -eq 0 ]
    [[ "$output" == *"size=1024"$'\n'* ]]
    [ -f "$HOME/victim/keep" ]
    [ ! -e "$TEMP/link" ]
    [ ! -L "$TEMP/link" ]
    [ ! -e "$TEMP/sub" ]
}

@test "ps: temp cleanup does not follow a directory swapped for a link after enumeration" {
    export TEMP="$HOME/tmp" SystemRoot="$HOME/Windows"
    mkdir -p "$TEMP/x" "$HOME/victim" "$SystemRoot"
    echo d >"$TEMP/x/decoy"
    echo keep >"$HOME/victim/important.txt"
    run ps '. (Join-Path $env:PSLIB "clean/Temp.ps1")
        $items = @(Get-ChildItem -LiteralPath $env:TEMP -Force)
        foreach ($i in $items) { $null = $i.Attributes }
        Remove-Item -Recurse -Force (Join-Path $env:TEMP "x")
        New-Item -ItemType SymbolicLink -Path (Join-Path $env:TEMP "x") -Target (Join-Path $env:HOME "victim") | Out-Null
        foreach ($i in $items) { _Temp-Remove-NoFollow $i }
        "victim=$(Test-Path (Join-Path $env:HOME "victim/important.txt"))"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"victim=True"* ]]
    [ -f "$HOME/victim/important.txt" ]
    [ ! -e "$TEMP/x" ]
}

@test "ps: temp cleanup stops emptying a directory that became a link under it" {
    export TEMP="$HOME/tmp" SystemRoot="$HOME/Windows"
    mkdir -p "$TEMP/d" "$HOME/victim"
    echo a >"$TEMP/d/a"; echo b >"$TEMP/d/b"
    echo keep >"$HOME/victim/important.txt"
    run ps '. (Join-Path $env:PSLIB "clean/Temp.ps1")
        $dir = Get-Item -LiteralPath (Join-Path $env:TEMP "d")
        $script:Swapped = $false
        # The first fresh attribute read of a child swaps the parent for a link.
        function _Temp-Is-Link-Now {
            param([string]$Path)
            if ((-not $script:Swapped) -and ($Path -like "*/d/*")) {
                $script:Swapped = $true
                Remove-Item -Recurse -Force $dir.FullName
                New-Item -ItemType SymbolicLink -Path $dir.FullName -Target (Join-Path $env:HOME "victim") | Out-Null
            }
            return (([int][IO.File]::GetAttributes($Path)) -band [int][IO.FileAttributes]::ReparsePoint) -ne 0
        }
        try { _Temp-Remove-NoFollow $dir } catch {}
        "swapped=$($script:Swapped)"
        "victim=$(Test-Path (Join-Path $env:HOME "victim/important.txt"))"'
    [[ "$output" == *"swapped=True"* ]]
    [[ "$output" == *"victim=True"* ]]
    [ -f "$HOME/victim/important.txt" ]
}

@test "ps: temp cleanup does not empty a directory whose handle cannot be taken as a plain directory" {
    export TEMP="$HOME/tmp" SystemRoot="$HOME/Windows"
    mkdir -p "$TEMP/d" "$HOME/victim"
    echo a >"$TEMP/d/a"
    run ps '. (Join-Path $env:PSLIB "clean/Temp.ps1")
        function _Temp-Open-Dir { param([string]$Path) return $null }
        $dir = Get-Item -LiteralPath (Join-Path $env:TEMP "d")
        try { _Temp-Remove-NoFollow $dir; "no throw" } catch { "refused" }
        "child=$(Test-Path (Join-Path $env:TEMP "d/a"))"'
    [[ "$output" == *"refused"* ]]
    [[ "$output" == *"child=True"* ]]
}

@test "ps: temp cleanup holds the directory handle while emptying it and releases it before the delete" {
    export TEMP="$HOME/tmp" SystemRoot="$HOME/Windows"
    mkdir -p "$TEMP/d"
    echo a >"$TEMP/d/a"
    run ps '. (Join-Path $env:PSLIB "clean/Temp.ps1")
        $script:Handle = [IO.MemoryStream]::new()
        $script:Held = @()
        function _Temp-Open-Dir { param([string]$Path) return $script:Handle }
        $real = ${function:_Temp-Is-Link-Now}
        function _Temp-Is-Link-Now { param([string]$Path) if ($Path -like "*/d/a") { $script:Held += $script:Handle.CanRead }; return (& $real $Path) }
        $dir = Get-Item -LiteralPath (Join-Path $env:TEMP "d")
        _Temp-Remove-NoFollow $dir
        "held=$($script:Held -join ",") released=$(-not $script:Handle.CanRead) gone=$(-not (Test-Path $dir.FullName))"'
    [[ "$output" == *"held=True released=True gone=True"* ]]
}

@test "ps: temp cleanup deletes a file through the file API, never Remove-Item" {
    export TEMP="$HOME/tmp"
    mkdir -p "$TEMP"; echo x >"$TEMP/ro.txt"; chmod a-w "$TEMP/ro.txt"
    # Remove-Item follows a junction swapped in on Windows: it must not be the path taken.
    run ps '. (Join-Path $env:PSLIB "clean/Size.ps1"); . (Join-Path $env:PSLIB "clean/Temp.ps1")
        function Remove-Item { throw "Remove-Item used" }
        _Temp-Remove-NoFollow (Get-Item -LiteralPath (Join-Path $env:TEMP "ro.txt")); "done"'
    [ "$status" -eq 0 ]
    [ ! -e "$TEMP/ro.txt" ]
}
