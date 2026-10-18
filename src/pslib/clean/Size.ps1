# Size formatting shared by the cleaning steps and the summary.

# Format size $Kibibytes, in KiB, as 812.0MB or 1.2GB.
function Size-Format-KB {
    param([double]$Kibibytes)
    $mebibytes = $Kibibytes / 1024
    if ($mebibytes -ge 1024) { return ('{0:0.0}GB' -f ($mebibytes / 1024)).Replace(',', '.') }
    return ('{0:0.0}MB' -f $mebibytes).Replace(',', '.')
}
