#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "diff_compute: underscores and multi-version packages give one line per version that came or went" {
    printf 'apt\tgone\t2.0\npacman\tpython-typing_extensions\t4.1\napt\tfoo_bar\t1.0\nrpm\tlib\t1\nrpm\tkernel\t6.2\nrpm\tkernel\t6.3\napt\tgone\t2.0\napt\tsame\t1\n' | sort >"$HOME/b"
    printf 'pacman\tpython-typing_extensions\t4.2\napt\tfoo_bar\t1.1\nrpm\tlib\t2\nrpm\tlib\t3\nrpm\tkernel\t6.2\nrpm\tkernel\t6.3\nrpm\tkernel\t6.4\napt\tnew\t0.1\napt\tsame\t1\n' | sort >"$HOME/a"
    run sys_lib 'diff_compute "$HOME/b" "$HOME/a" "$HOME/d"; cat "$HOME/d"; echo "n=$(diff_count_changed "$HOME/d")"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "+	apt	new	0.1" ]
    [ "${lines[1]}" = "+	rpm	kernel	6.4" ]
    [ "${lines[2]}" = "+	rpm	lib	2" ]
    [ "${lines[3]}" = "+	rpm	lib	3" ]
    [ "${lines[4]}" = "-	apt	gone	2.0" ]
    [ "${lines[5]}" = "-	rpm	lib	1" ]
    [ "${lines[6]}" = "~	apt	foo_bar	1.0 -> 1.1" ]
    [ "${lines[7]}" = "~	pacman	python-typing_extensions	4.1 -> 4.2" ]
    [ "${lines[8]}" = "n=8" ]
}

@test "diff_compute: missing snapshot gives an empty diff" {
    run sys_lib 'echo x >"$HOME/d"; diff_compute "$HOME/none" "$HOME/none2" "$HOME/d"; wc -c <"$HOME/d"'
    [ "$output" = "0" ]
}

@test "diff_compute: empty before snapshot reads every package as added" {
    : >"$HOME/b"
    printf 'flatpak\torg.x\t1.0\n' >"$HOME/a"
    run sys_lib 'diff_compute "$HOME/b" "$HOME/a" "$HOME/d"; cat "$HOME/d"'
    [ "$status" -eq 0 ]
    [ "$output" = "+	flatpak	org.x	1.0" ]
    printf 'flatpak\torg.x\t1.0\n' >"$HOME/b"
    : >"$HOME/a"
    run sys_lib 'diff_compute "$HOME/b" "$HOME/a" "$HOME/d"; cat "$HOME/d"'
    [ "$output" = "-	flatpak	org.x	1.0" ]
}

@test "diff_show: attack OSC 52, CSI and C1 introducers in a package name and version, expected stripped" {
    printf '+\tflatpak\tapp\033]52;c;SGVsbG8=\007x\t1.0\xc2\x9d0;t\xc2\x9c\n~\tbrew\tfoo\t1\033[2J -> 2\n' >"$HOME/d"
    run sys_lib 'diff_show "$HOME/d" >"$HOME/out"'
    [ "$status" -eq 0 ]
    [ "$(grep -c ']52' "$HOME/out" || true)" = "0" ]
    [ "$(grep -c '\[2J' "$HOME/out" || true)" = "0" ]
    [ "$(LC_ALL=C grep -c $'\xc2[\x80-\x9f]' "$HOME/out")" = "0" ]
    grep -q 'appx' "$HOME/out"
}
