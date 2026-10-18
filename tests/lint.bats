#!/usr/bin/env bats
# Static checks over the PowerShell sources, run through pwsh's own parser.

@test "every PowerShell file parses without errors" {
    command -v pwsh >/dev/null || skip "pwsh not installed"
    ROOT="${BATS_TEST_DIRNAME}/.." run pwsh -NoProfile -NonInteractive -Command '
        $bad = 0
        foreach ($f in Get-ChildItem -Path $env:ROOT -Recurse -Filter *.ps1) {
            $errors = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$errors)
            foreach ($e in $errors) { Write-Output "$($f.FullName):$($e.Extent.StartLineNumber): $($e.Message)"; $bad++ }
        }
        exit $bad'
    echo "$output"
    [ "$status" -eq 0 ]
}

# List each node under directory $1 whose syntax Windows PowerShell 5.1
# cannot parse (pwsh 7 only), one "file:line: kind" per line, and exit with
# their count.
ps51_check() {
    ROOT="$1" pwsh -NoProfile -NonInteractive -Command '
        $bad = 0
        foreach ($f in Get-ChildItem -Path $env:ROOT -Recurse -Filter *.ps1) {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
            $hits = $ast.FindAll({
                param($n)
                $n -is [System.Management.Automation.Language.PipelineChainAst] -or
                $n -is [System.Management.Automation.Language.TernaryExpressionAst] -or
                ($n -is [System.Management.Automation.Language.BinaryExpressionAst] -and $n.Operator -eq "QuestionQuestion") -or
                ($n -is [System.Management.Automation.Language.AssignmentStatementAst] -and $n.Operator -eq "QuestionQuestionEquals") -or
                ($n -is [System.Management.Automation.Language.MemberExpressionAst] -and $n.NullConditional) -or
                ($n -is [System.Management.Automation.Language.IndexExpressionAst] -and $n.NullConditional)
            }, $true)
            foreach ($h in $hits) {
                $kind = $h.GetType().Name
                if ($h.Operator) { $kind += " $($h.Operator)" }
                if ($h.NullConditional) { $kind += " null-conditional" }
                Write-Output "$($f.FullName):$($h.Extent.StartLineNumber): $kind"
                $bad++
            }
        }
        exit $bad'
}

@test "every PowerShell file uses only syntax Windows PowerShell 5.1 parses" {
    command -v pwsh >/dev/null || skip "pwsh not installed"
    run ps51_check "${BATS_TEST_DIRNAME}/.."
    echo "$output"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "the 5.1 syntax check flags each pwsh 7 only construct" {
    command -v pwsh >/dev/null || skip "pwsh not installed"
    local d
    d="$(mktemp -d)"
    printf '%s\n' 'a && b' 'a || b' '$x = $a ? 1 : 2' '$x = $a ?? 1' '$x ??= 1' '${a}?.B' '${a}?[0]' '$ok = $a -and $b' >"$d/s.ps1"
    run ps51_check "$d"
    rm -rf "$d"
    echo "$output"
    [ "$status" -eq 7 ]
    [[ "$output" == *"s.ps1:1: PipelineChainAst"* ]]
    [[ "$output" == *"s.ps1:2: PipelineChainAst"* ]]
    [[ "$output" == *"s.ps1:3: TernaryExpressionAst"* ]]
    [[ "$output" == *"s.ps1:4: BinaryExpressionAst QuestionQuestion"* ]]
    [[ "$output" == *"s.ps1:5: AssignmentStatementAst QuestionQuestionEquals"* ]]
    [[ "$output" == *"s.ps1:6: MemberExpressionAst null-conditional"* ]]
    [[ "$output" == *"s.ps1:7: IndexExpressionAst null-conditional"* ]]
    [[ "$output" != *"s.ps1:8:"* ]]
}

@test "shell sources: CI error-level shellcheck list exits 0" {
    command -v shellcheck >/dev/null || skip "shellcheck not installed"
    cd "${BATS_TEST_DIRNAME}/.."
    shopt -s globstar nullglob
    run shellcheck -S error install.sh uninstall.sh \
        src/emerger.sh src/lib/**/*.sh share/plugins/*.sh share/profiles/*.sh completions/up.bash
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "shell sources: CI warning-level shellcheck list exits 0" {
    command -v shellcheck >/dev/null || skip "shellcheck not installed"
    cd "${BATS_TEST_DIRNAME}/.."
    shopt -s globstar nullglob
    run shellcheck -S warning install.sh uninstall.sh \
        src/emerger.sh src/lib/**/*.sh share/plugins/*.sh share/profiles/*.sh completions/up.bash
    echo "$output"
    [ "$status" -eq 0 ]
}

@test "the CI warnings leg cannot pass on a failure: no || true after shellcheck" {
    run awk '/Lint \(warnings\)/{w=1} w && /\|\| true/{exit 1}' "${BATS_TEST_DIRNAME}/../.github/workflows/ci.yml"
    [ "$status" -eq 0 ]
}

@test "the CI tests job fails when pwsh is missing, so tests/ps_*.bats cannot skip green" {
    run awk '/^  tests:/{t=1} t && /command -v pwsh &&/{f=1} t && /run: bats tests\//{if(!f) exit 1; ok=1} END{exit !ok}' "${BATS_TEST_DIRNAME}/../.github/workflows/ci.yml"
    [ "$status" -eq 0 ]
}
