#!/usr/bin/env bash
# Example eMerger plugin. Copy to ~/.config/emerger/managers.d/<slug>.sh
# and edit. The slug below becomes the manager name shown by eMerger.

# Read by the plugin loader.
# shellcheck disable=SC2034
PM_PLUGIN_SLUG=example

# Return 0 if the tool is installed on this system.
pm_example_detect() {
    command -v example-tool >/dev/null 2>&1
}

# Return 0 if the tool needs root. Optional: without it, never.
pm_example_needs_sudo() { return 1; }

# Return 0 if the tool can run beside other managers under --parallel.
pm_example_parallel() { return 0; }

# Return 0 to run the tool only under --dev.
pm_example_dev() { return 1; }

# Return 0 if pm_example_run honours ARG_SECURITY. Without it, --security
# skips the plugin.
pm_example_security() { return 1; }

# Print the section icon (a plug emoji).
pm_example_icon() { printf '\xf0\x9f\x94\x8c'; }

# Refresh and upgrade through run_cmd, which honours --dry-run, --verbose,
# retries and logging. Return non-zero on failure.
pm_example_run() {
    run_cmd "example refresh" example-tool refresh || return 1
    run_cmd "example upgrade" example-tool upgrade -y || return 1
    return 0
}
