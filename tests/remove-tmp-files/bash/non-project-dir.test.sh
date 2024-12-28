#!/bin/bash

echo "Test on non-project directory"
set_up

$CMD "$TMP_DIR/dir_a" || true

assert_exists "$TMP_DIR/dir_a/foo.txt"
