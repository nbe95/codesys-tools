#!/bin/bash

echo "Test on nested directory structure"
set_up

$cmd "$tmp_dir/dir_c" || true

assert_exists "$tmp_dir/dir_c/dir_d/dir_e/nothing.txt"

assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.projectarchive"
assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.backup"
assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.lock"
assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.opt"
assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/foo.~u"
assert_exists "$tmp_dir/dir_c/dir_d/dir_f/dir_g/DEFAULT.DFR"
