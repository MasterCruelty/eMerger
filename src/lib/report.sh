#!/usr/bin/env bash
# Export the last run's summary + diff as Markdown.

report_export() {
    local out="${1:-$EMERGER_STATE/last-report.md}"
    local hist="$EMERGER_STATE/history.jsonl"
    {
        printf '# eMerger report\n\n'
        printf '- host: `%s`\n' "$(hostname 2>/dev/null || echo '?')"
        printf '- date: `%s`\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        printf '- distro: `%s`\n' "$(sys_distro)"
        printf '- version: `eMerger %s`\n\n' "${EMERGER_VERSION:-?}"
        if [[ -f $hist ]]; then
            printf '## Last run\n\n```json\n'
            tail -n 1 "$hist"
            printf '```\n\n'
        fi
        if (( ${#SUMMARY_MANAGERS[@]:-0} > 0 )); then
            printf '## Managers\n\n'
            local i
            for i in "${!SUMMARY_MANAGERS[@]}"; do
                printf '- `%s` - **%s**\n' "${SUMMARY_MANAGERS[i]}" "${SUMMARY_RESULTS[i]}"
            done
            printf '\n'
        fi
        if [[ -s $DIFF_LAST ]]; then
            printf '## Package changes\n\n'
            printf '| kind | manager | package | version |\n|---|---|---|---|\n'
            awk -F'\t' '{printf "| %s | %s | %s | %s |\n", $1, $2, $3, $4}' "$DIFF_LAST"
            printf '\n'
        fi
        if (( REBOOT_NEEDED )); then
            printf '> **Reboot recommended** - %s\n\n' "$REBOOT_REASON"
        fi
    } >"$out"
    ui_ok "Report written to $out"
}
