#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "progress_summarize: apt counts the packages to remove" {
    echo "3 upgraded, 1 newly installed, 2 to remove and 0 not upgraded." >"$HOME/apt.out"
    run sys_lib 'progress_summarize apt "$HOME/apt.out"'
    [ "$status" -eq 0 ]
    [ "$output" = "3 upgraded, 1 new, 2 removed" ]
}

@test "progress_feed: zero-padded counters read as decimal" {
    run sys_lib 'progress_feed pacman "(08/24) upgrading foo" 2>&1; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
                 progress_reset
                 progress_feed brew "==> Upgrading 09 outdated packages:" 2>&1
                 progress_feed brew "==> Upgrading foo" 2>&1; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "8/24" ]
    [ "${lines[1]}" = "1/9" ]
}

@test "progress_summarize returns 0 with no match" {
    run lib 'f=$(mktemp); echo nothing >"$f"; out=$(progress_summarize pacman "$f"); echo "rc=$? [$out]"'
    [ "$output" = "rc=0 []" ]
}

@test "progress: apt dlstatus sets the file counter, pmstatus the percent and message" {
    run lib 'progress_feed apt "dlstatus:3:0.0000:Retrieving file 3 of 12"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL $PROGRESS_PERCENT"
             progress_feed apt "pmstatus:libssl3:45.4545:Unpacking libssl3 (arm64)"; echo "$PROGRESS_TOTAL $PROGRESS_PERCENT $PROGRESS_MESSAGE"'
    [ "${lines[0]}" = "3/12 -1" ]
    [ "${lines[1]}" = "0 45 Unpacking libssl3 (arm64)" ]
}

@test "progress: (n/N) counters of the other managers set current and total" {
    run lib '
        progress_feed pacman "(3/24) upgrading linux-firmware"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
        progress_feed zypper "Retrieving: vim-9.1 (5/9)"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
        progress_feed dnf "  Upgrading        : kernel-6.1.x86_64      7/30"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
        progress_feed emerge ">>> Emerging (2 of 8) app-misc/foo-1.2::gentoo"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
        progress_feed flatpak "Updating 1/4…"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"
        progress_feed pip "[2/6] requests"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL $PROGRESS_MESSAGE"
        progress_feed snap "Download snap \"core\" 37% 1.2MB/s"; echo "$PROGRESS_PERCENT"'
    [ "${lines[0]}" = "3/24" ]
    [ "${lines[1]}" = "5/9" ]
    [ "${lines[2]}" = "7/30" ]
    [ "${lines[3]}" = "2/8" ]
    [ "${lines[4]}" = "1/4" ]
    [ "${lines[5]}" = "2/6 requests" ]
    [ "${lines[6]}" = "37" ]
}

@test "progress: brew counts each upgrade against the outdated total" {
    run lib 'progress_feed brew "==> Upgrading 3 outdated packages:"
             progress_feed brew "==> Upgrading git"; progress_feed brew "==> Upgrading jq"
             echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"'
    [ "$output" = "2/3" ]
}

@test "progress: (0/0) and (9/3) are ignored" {
    run lib 'progress_feed pacman "(0/0) nothing"; progress_feed pacman "(9/3) bogus"; echo "$PROGRESS_CURRENT/$PROGRESS_TOTAL"'
    [ "$output" = "0/0" ]
}
