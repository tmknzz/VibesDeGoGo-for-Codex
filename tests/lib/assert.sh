#!/bin/bash

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

assert_eq() {
    local expected="$1" actual="$2" message="$3"
    [ "$expected" = "$actual" ] || fail "${message}: expected '${expected}', got '${actual}'"
}

assert_ne() {
    local not_expected="$1" actual="$2" message="$3"
    [ "$not_expected" != "$actual" ] || fail "${message}: did not expect '${actual}'"
}

assert_exit_code() {
    local expected="$1" actual="$2" message="$3"
    [ "$expected" -eq "$actual" ] || fail "${message}: expected exit ${expected}, got ${actual}"
}

assert_file_exists() {
    local path="$1" message="$2"
    [ -e "$path" ] || fail "${message}: missing ${path}"
}

assert_file_not_exists() {
    local path="$1" message="$2"
    [ ! -e "$path" ] || fail "${message}: unexpected ${path}"
}

assert_contains() {
    local haystack="$1" needle="$2" message="$3"
    case "$haystack" in
        *"$needle"*) ;;
        *) fail "${message}: '${needle}' not found" ;;
    esac
}
