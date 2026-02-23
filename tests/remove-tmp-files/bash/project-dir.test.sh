#!/bin/bash

echo "Test on project directory"
set_up

$CMD "$TMP_DIR/dir_b" || true

assert_exists "$TMP_DIR/dir_b/foo.project"
assert_not_exists "$TMP_DIR/dir_b/foo.backup"
assert_not_exists "$TMP_DIR/dir_b/foo.lock"
assert_not_exists "$TMP_DIR/dir_b/foo.opt"
assert_not_exists "$TMP_DIR/dir_b/foo.~u"
assert_not_exists "$TMP_DIR/dir_b/DEFAULT.DFR"

assert_exists "$TMP_DIR/dir_b/bar.txt"
assert_exists "$TMP_DIR/dir_b/foobar.project.txt"
