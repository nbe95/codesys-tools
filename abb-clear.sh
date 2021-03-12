#!/bin/bash

# CLI formatter
bold="\033[1m"
normal="\033[0m"

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
dir=$1
if [[ -z "$dir" ]]; then
    dir="."
fi

# Check if directory exists
if ! [[ -d "$dir" ]]; then
    echo -r "${bold}Error:${normal} Directory '$dir' does not exist."
    exit 10
fi

# Find all ABB project directories
find_options=( -L )
find_options+=( $dir )
if [[ -z "$flag_rec" ]]; then
    find_options+=( -maxdepth 0 )
fi
find_options+=( -type f )
find_options+=( -regex '.*\.project\(archive\)?' )
find_options+=( -printf '%h\n' )

# Regex for any temporary files
regex="\(.+\.\(opt\|backup\|lock\|~u\)\|DEFAULT\.DFR\)"

# Search each project directory
find ${find_options[@]} | uniq | while read dir; do
    echo -e "${bold}Directory:${normal} $dir"

    # Search for temporary files
    files=$(find $dir -maxdepth 1 -type f -regex $regex -print)

    # Any files found?
    if [[ "$files" ]]; then

        # Iterate over each file
        echo "$files" | while read file; do

            # Try to remove this file
            rm $file

            # Print filename and indication mark
            if [[ "$?" -eq "0" ]]; then
                echo -e "  ${bold}["$'\u2714'"]${normal} Removed $file"
            else
                echo -e "  ${bold}["$'\u274c'"]${normal} Could not remove $file"
            fi
         done
    else
        # Print information that no files were found
        echo -e "  ${bold}[i]${normal} No temporary files found"
    fi
    echo ""
done

exit 0
