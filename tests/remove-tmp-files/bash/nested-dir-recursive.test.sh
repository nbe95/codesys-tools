#!/bin/bash

echo "Test on nested directory structure"
set_up

$cmd -r "$tmp_dir/dir_c" || true

assert_exists "$tmp_dir/dir_c/dir_d/dir_e/nothing.txt"

assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.projectarchive"
assert_not_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.backup"
assert_not_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.lock"
assert_not_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.opt"
assert_not_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.~u"
assert_not_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/DEFAULT.DFR"
