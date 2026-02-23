#!/bin/bash

test_dir="$(dirname "$0")"
CMD="$test_dir/../../../remove-tmp-files.sh"
INPUT_DIR="$test_dir/../input"
TMP_DIR="$test_dir/../tmp"

export CMD
export INPUT_DIR
export TMP_DIR

source "$test_dir/../../util/assert/assert.sh"

# Helper functions for file checking
assert_exists() {
    if [ -f "$1" ]; then e=true; else e=false; fi
    assert_true "$e" "File $1 does not exist."
}

assert_not_exists() {
    if [ -f "$1" ]; then e=true; else e=false; fi
    assert_false "$e" "File $1 does exist."
}

# Setup routine for each individual test
set_up() {
    rm -rf "$TMP_DIR"
    cp -r "$INPUT_DIR" "$TMP_DIR"
}


# Run all unit test files
set -e
for file in "$test_dir"/*.test.sh; do
    source "$file"
done
