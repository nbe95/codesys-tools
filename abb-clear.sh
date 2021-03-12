#!/bin/bash

# Regex for all temporary files
regex=".+\.\(opt\|backup\|DFR\|lock\|~u\)"

# How many files would be affected?
count=$(find . -maxdepth 1 -regex $regex -type f -printf 'x' | wc -c)

# Try to delete all matching files
files=$(find . -maxdepth 1 -regex $regex -type f -print -delete 2>/dev/null)
code=$?

# Print list of removed files
if [[ "$count" -gt "0" ]]; then
    echo "$files"

    # Print a separating line as long as the longest filename
    chars=$(echo "$files" | awk '{ print length }' | sort -n | tail -1)
    printf "━%.0s" $(seq 1 $chars)
    echo ""
fi

# Print error message if necessary
if [[ "$code" -ne "0" ]]; then
    echo "Error while trying to remove all temporary files!"
    exit $code
fi

# If everything went ok, print how many files have been removed
if (( $count == 0 )); then
    echo "No files removed."
else
    echo "$count file(s) removed."
fi

exit 0
