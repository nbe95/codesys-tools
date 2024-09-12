#!/bin/bash

# CLI formatter
normal="\033[0m"
bold="\033[1m"
red="\e[31m"
green="\e[32m"
gray="\e[90m"
yellow="\e[93m"

# Usage
usage() { echo -e "${bold}Usage:${normal} $(basename "$0") [-r] [<directory>]" 1>&2; exit 0; }

# Parse argument options
if [[ "$#" -gt "2" ]]; then usage; fi
while getopts ":hr" opt; do
    case "${opt}" in
        r) flag_rec=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# Directory provided? If not, use current directory
if [[ -n "$dir" ]]; then
    dir="$(realpath "$1")"
else
    dir="$(pwd)"
fi

# Check if the given directory exists
if ! [[ -d "$dir" ]]; then
    echo -e "[${bold}${red}"$'\u2717'"${normal}] Directory '$dir' does not exist."
    exit 1
fi

# Regex to identify ABB project directories and temporary files
regex_prjdir=".*\.project\(archive\)?"
regex_tmpfiles="\(DEFAULT\.DFR\|.+\.\(opt\|backup\|lock\|~u\)\)"

# Find any ABB project directories
find_options=()
if [[ -z "$flag_rec" ]]; then
    find_options+=( -maxdepth 1 )
fi
find_options+=( -type f )

# Catch errors due to missing permissions
if ! prj_dirs=$(find -L "$dir" "${find_options[@]}" -regex "$dir/$regex_prjdir" -printf "%h\n"); then
    echo ""
    echo -e "[${bold}${yellow}!${normal}] Warning: Could not access all specified paths!"
    echo ""
fi

# Define a file as error indicator (survives even subshell magic)
err_ind=./.a-b-clear-error

# Sort results and use any path only once (unique)
prj_dirs=$(echo "$prj_dirs" | sort -u)

# Check for find results
if [[ "$prj_dirs" ]]; then

    # Search each project directory
    echo "$prj_dirs" | while read -r prj_dir; do
        echo -e "${bold}Project directory: $prj_dir/${normal}"

        # Search for temporary files
        files=$(find "$prj_dir" -maxdepth 1 -type f -regex "${prj_dir}/${regex_tmpfiles}" -print 2>/dev/null)

        # Any files found?
        if [[ "$files" ]]; then

            # Iterate over each file
            echo "$files" | while read -r file; do

                # Try to remove this file
                err=0
                if command -v trash &> /dev/null; then
                    # Use `trash` command if available
                    if ! trash "$file" &> /dev/null; then err=1; fi
                else
                    # Otherwise, remove file by the traditional way (irreversible)
                    if ! rm "$file" &> /dev/null; then err=1; fi
                fi

                # Print filename and indication mark
                if [ $err ]; then
                    echo -e "  [${bold}${green}"$'\u2713'"${normal}] ${file##*/} removed."
                else
                    echo -e "  [${bold}${red}"$'\u2717'"${normal}] ${file##*/} could not be removed."
                    touch "$err_ind"
                fi
             done
        else
             # Print information that no files were found
            echo -e "  [${bold}${gray}i${normal}] No temporary files found."
        fi
        echo ""
    done
else
    # Print information that no project directories were found
    echo -e "[${bold}${yellow}!${normal}] No project directories found."
    exit 2
fi

# Exit with error code if error(s) occured during removal
if [[ -f "$err_ind" ]]; then
    rm -f "$err_ind"
    exit 10
fi

# Exit gracefully
exit 0
