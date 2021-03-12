#!/bin/bash

# CLI formatter
bold="\033[1m"
normal="\033[0m"
green="\e[32m"
red="\e[31m"
yellow="\e[93m"
gray="\e[90m"

# Usage
usage() { echo -e "${bold}Usage:${normal} $0 [-r] [<directory>]" 1>&2; exit 0; }

# Parse argument options
if [[ "$#" -gt "2" ]]; then usage; fi
while getopts ":hr" opt; do
    case "${opt}" in
        h) usage ;;
        r) flag_rec=1 ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

# Directory provided? If not, use current directory
dir="$1"
if [[ -z "$dir" ]]; then
    dir="."
fi

# Check if directory exists
if ! [[ -d "$dir" ]]; then
    echo -e "${bold}Error:${normal} Directory '$dir' does not exist."
    exit 10
fi

# Find all ABB project directories
find_options=()
if [[ -z "$flag_rec" ]]; then
    find_options+=( -maxdepth 1 )
fi
find_options+=( -type f )
find_options+=( -regex ".*\.project\(archive\)?" )
find_options+=( -printf "%h\n" )

# Regex for any temporary files
regex="\(DEFAULT\.DFR\|.+\.\(opt\|backup\|lock\|~u\)\)"

# Any project directories found?
prj_dirs=$(find -L "$dir" ${find_options[@]} | sort -u)
if [[ "$prj_dirs" ]]; then

    # Search each project directory
    echo "$prj_dirs" | while read prj_dir; do
        echo -e "${bold}Project directory: $prj_dir/${normal}"

        # Search for temporary files
        files=$(find "$prj_dir" -maxdepth 1 -type f -regex "${prj_dir}/${regex}" -print 2>/dev/null)

        # Any files found?
        if [[ "$files" ]]; then

            # Iterate over each file
            echo "$files" | while read file; do

                # Try to remove this file
                rm "$file" &>/dev/null

                # Print filename and indication mark
                if [[ "$?" -eq "0" ]]; then
                    echo -e "  [${bold}${green}"$'\u2713'"${normal}] ${file##*/} removed."
                else
                    echo -e "  [${bold}${red}"$'\u2717'"${normal}] ${file##*/} could not be removed."
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
fi
exit 0
