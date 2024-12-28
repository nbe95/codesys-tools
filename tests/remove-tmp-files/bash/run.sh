#!/bin/bash

test_dir="$(dirname "$0")"
cmd="$test_dir/../../../remove-tmp-files.sh"
input_dir="$test_dir/../input"
tmp_dir="$test_dir/../tmp"

source "$test_dir/../../util/assert/assert.sh"

# Helper functions for file checking
assert_exists() {
    if [ -f "$1" ]; then exists=true; else exists=false; fi
    assert_true "$exists" "File $1 does not exist."
}

assert_not_exists() {
    if [ -f "$1" ]; then exists=true; else exists=false; fi
    assert_false "$exists" "File $1 does exist."
}

# Setup routine for each individual test
set_up() {
    rm -rf "$tmp_dir"
    cp -r "$input_dir" "$tmp_dir"
}


# Run all unit test files
set -e
for file in "$test_dir"/*.test.sh; do
    source "$file"
done
