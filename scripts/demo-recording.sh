#!/bin/bash
set -euo pipefail
shopt -s nullglob

fail() {
    printf '%s\n' "$*" >&2
    exit 1
}

[[ $OSTYPE == darwin* ]] || fail 'This demo requires macOS.'
[[ $# -eq 1 ]] || fail "Usage: $0 /absolute/path/to/borrow"
borrow=$1
[[ $borrow == /* && -f $borrow && -x $borrow ]] || fail 'Provide an absolute path to the executable Borrow CLI.'

root=$(mktemp -d /private/tmp/borrow-demo.XXXXXXXX)

run_case() {
    local name=$1 task=$2 expected_exit=$3 expected_finding=$4
    local status=0
    local -a reports

    "$borrow" run --timeout 10 --wake off --output "$root/$name" -- "$task" >"$root/$name.log" 2>&1 || status=$?
    [[ $status -eq $expected_exit ]] ||
        fail "$name: expected exit $expected_exit, got $status. See $root/$name.log for details."

    reports=("$root/$name"/*/report.md)
    [[ -n ${reports[0]:-} && ${#reports[@]} -eq 1 && -s ${reports[0]} ]] ||
        fail "$name: expected one nonempty report under $root/$name."
    /usr/bin/grep -Fqx -- "### Command exit — $expected_finding" "${reports[0]}" ||
        fail "$name: command exit finding differs from expected. See ${reports[0]} for details."
    /usr/bin/grep -Fq -- "Observed foreground process exit $expected_exit." "${reports[0]}" ||
        fail "$name: the report does not record exit $expected_exit. See ${reports[0]} for details."
    printf '%s\n' "${reports[0]}"
}

success_report=$(run_case success /usr/bin/true 0 observed)
failure_report=$(run_case failure /usr/bin/false 1 failed)
printf '%s\n' "$success_report" "$failure_report"
