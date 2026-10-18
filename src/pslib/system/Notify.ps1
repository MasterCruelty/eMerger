# Best-effort desktop notification. Uses BurntToast if installed, otherwise no-op.

# Show a desktop notification with the run's result when BurntToast is
# installed, errors ignored.
function Notify-Send-Result {
    if (-not (Get-Module -ListAvailable -Name BurntToast -ErrorAction SilentlyContinue)) { return }
    try {
        Import-Module BurntToast -ErrorAction Stop
        $errors = Summary-Fail-Count
        $total  = @($script:Summary).Count
        $message = if ($errors -gt 0) { "Finished with $errors error(s)." }
               else               { "$total manager(s) updated." }
        New-BurntToastNotification -Text 'eMerger', $message -ErrorAction SilentlyContinue
    } catch {}
}
