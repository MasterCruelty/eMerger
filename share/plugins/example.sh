#!/usr/bin/env bash
# Example eMerger plugin. Copy to ~/.config/emerger/managers.d/<slug>.sh
# and edit. The slug below becomes the manager name shown by eMerger.

PM_PLUGIN_SLUG=example

pm_example_detect() {
    # Return 0 if the tool is installed on this system.
    command -v example-tool >/dev/null 2>&1
}

pm_example_needs_sudo() { return 1; }   # remove or flip to 0 if sudo is needed
pm_example_parallel()   { return 0; }   # safe to run concurrently with others
pm_example_dev()        { return 1; }   # return 0 to gate under --dev

pm_example_icon() { printf '\xf0\x9f\x94\x8c'; }  # plug emoji

pm_example_run() {
    # Use run_cmd so --dry-run, --verbose, retry, logging all work.
    run_cmd "example refresh" example-tool refresh || return 1
    run_cmd "example upgrade" example-tool upgrade -y || return 1
    return 0
}
