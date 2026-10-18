# Clean the %TEMP% folders without following reparse points. Prompts
# unless -y.

# Return $true when the file system entry at $Path is a junction, symlink or
# other reparse point, read now (never the attributes cached by an earlier
# enumeration). A path that cannot be read counts as a link.
function _Temp-Is-Link-Now {
    param([string]$Path)
    try { return (([int][IO.File]::GetAttributes($Path)) -band [int][IO.FileAttributes]::ReparsePoint) -ne 0 } catch { return $true }
}

# Return $true when $Item is a reparse point, never descended into so an admin
# run cannot be steered outside the temp folder.
function _Temp-Is-Reparse {
    param($Item)
    return (_Temp-Is-Link-Now $Item.FullName)
}

# Return the size of the regular files under $Path in whole KiB, not following
# reparse points.
function _Temp-Folder-Size-KB {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0 }
    try {
        $totalBytes = 0.0
        $stack = New-Object System.Collections.Generic.Stack[string]
        $stack.Push($Path)
        while ($stack.Count -gt 0) {
            foreach ($item in @(Get-ChildItem -LiteralPath $stack.Pop() -Force -ErrorAction SilentlyContinue)) {
                if (_Temp-Is-Reparse $item) { continue }
                if ($item.PSIsContainer) { $stack.Push($item.FullName) } else { $totalBytes += $item.Length }
            }
        }
        return [int64][math]::Round($totalBytes / 1KB)
    } catch { return 0 }
}

# Open directory $Path with reparse-point semantics and return a handle that
# denies other processes the right to rename or delete it while held, after
# checking the reparse attribute on that same handle. Return $null when it is
# a link or cannot be opened. Off Windows (no such sharing mode) the result is
# $true for a plain directory.
function _Temp-Open-Dir {
    param([string]$Path)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        if (_Temp-Is-Link-Now $Path) { return $null }
        return $true
    }
    if (-not ('EmergerDirHandle' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;
public static class EmergerDirHandle {
    [StructLayout(LayoutKind.Sequential)]
    struct FileTime { public uint Low; public uint High; }
    [StructLayout(LayoutKind.Sequential)]
    struct ByHandleInfo {
        public uint Attributes; public FileTime Created; public FileTime Accessed; public FileTime Written;
        public uint Volume; public uint SizeHigh; public uint SizeLow; public uint Links; public uint IndexHigh; public uint IndexLow;
    }
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr security, uint disposition, uint flags, IntPtr template);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetFileInformationByHandle(SafeFileHandle handle, out ByHandleInfo info);
    public static SafeFileHandle Open(string path) {
        // List and read attributes; share read and write but not delete, so the directory cannot be renamed or replaced while held.
        SafeFileHandle handle = CreateFileW(path, 0x81, 3, IntPtr.Zero, 3, 0x02200000, IntPtr.Zero);
        if (handle.IsInvalid) return null;
        ByHandleInfo info;
        if (!GetFileInformationByHandle(handle, out info) || (info.Attributes & 0x400) != 0 || (info.Attributes & 0x10) == 0) { handle.Dispose(); return null; }
        return handle;
    }
}
'@
    }
    try { return [EmergerDirHandle]::Open($Path) } catch { return $null }
}

# Delete $Item. A reparse point loses only the link itself. A directory is
# pinned by a handle opened without delete sharing and checked for the reparse
# attribute on that handle, so it cannot be swapped for a link while its
# entries are enumerated and removed; the handle is released just before the
# final delete of the then empty directory (a link there is removed, never
# followed). Throws on the first failure.
function _Temp-Remove-NoFollow {
    param($Item)
    $path = $Item.FullName
    if (_Temp-Is-Link-Now $path) {
        if ($Item.PSIsContainer) {
            try { [IO.Directory]::Delete($path, $false); return } catch {}
        }
        [IO.File]::Delete($path)
        return
    }
    if ($Item.PSIsContainer) {
        $handle = _Temp-Open-Dir $path
        if ($null -eq $handle) { throw "$path is a link or cannot be pinned" }
        try {
            foreach ($child in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)) {
                if (_Temp-Is-Link-Now $path) { throw "$path became a link" }
                try { _Temp-Remove-NoFollow $child } catch {}
            }
        } finally {
            if ($handle -is [IDisposable]) { $handle.Dispose() }
        }
        if (_Temp-Is-Link-Now $path) { throw "$path became a link" }
        [IO.Directory]::Delete($path, $false)
        return
    }
    # File APIs act on the name given and never follow a link swapped in for it.
    $attributes = [IO.File]::GetAttributes($path)
    if ($attributes -band [IO.FileAttributes]::ReadOnly) {
        [IO.File]::SetAttributes($path, ($attributes -band (-bnot [IO.FileAttributes]::ReadOnly)))
    }
    [IO.File]::Delete($path)
}

# Empty the temp folders after a prompt (-y says yes) and add what was freed
# to SUMMARY_FREED_KB. Entries that cannot be removed are skipped.
function Clean-Temp {
    UI-Title 'Temp folders'
    $paths = @($env:TEMP, (Join-Path $env:LOCALAPPDATA 'Temp'), (Join-Path $env:SystemRoot 'Temp')) |
        Where-Object { $_ } | Select-Object -Unique
    $before = 0
    foreach ($path in $paths) { $before += (_Temp-Folder-Size-KB $path) }
    # Below 52 KiB the size prints as 0.0MB.
    if ($before -lt 52) { UI-Ok 'already clean'; return }
    UI-Muted ($paths -join ', ')

    if (-not (UI-Confirm 'Clean temp folders?' 'n' "($(Size-Format-KB $before))")) { UI-Muted 'skipped'; return }
    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would clean temp folders'; return }

    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        foreach ($item in @(Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue)) {
            try { _Temp-Remove-NoFollow $item } catch {}
        }
    }
    $after = 0
    foreach ($path in $paths) { $after += (_Temp-Folder-Size-KB $path) }
    $freed = [math]::Max([int64]0, [int64]($before - $after))
    $script:SUMMARY_FREED_KB += $freed
    $script:UI_LAST_ELAPSED = UI-Format-Elapsed $stopwatch.Elapsed
    UI-Done 'temp cleaned' (Size-Format-KB $freed)
}
