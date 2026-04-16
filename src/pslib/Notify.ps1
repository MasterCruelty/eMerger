# Best-effort desktop notification. Uses BurntToast if installed, otherwise no-op.

function Notify-Send-Result {
    if (-not (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue)) { return }
    try {
        Import-Module BurntToast -ErrorAction Stop
        $errors = @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count
        $total  = @($script:Summary).Count
        $msg = if ($errors -gt 0) { "Finished with $errors error(s)." }
               else               { "$total manager(s) updated." }
        New-BurntToastNotification -Text 'eMerger', $msg -ErrorAction SilentlyContinue
    } catch {}
}
