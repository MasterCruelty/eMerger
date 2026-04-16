#Requires -Version 5.1
# Thin wrapper for `up --self-update`.
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
$REPO = Split-Path -Parent $PSCommandPath
& "$REPO\src\emerger.ps1" --self-update @Arguments
