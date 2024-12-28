#!/bin/bash

echo "Test on non-project directory"
set_up

$cmd "$tmp_dir/dir_a" || true

assert_exists "$tmp_dir/dir_a/foo.txt"
