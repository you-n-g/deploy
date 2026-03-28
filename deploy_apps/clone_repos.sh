#!/bin/bash
# Clone personal repos (cheatsheets, farside).
# Usage: clone_repos.sh [-s]   -s = use SSH URLs (required for private repos)

USE_SSH=0
while getopts ":s" opt; do
    case $opt in
    s) USE_SSH=1 ;;
    \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    :)  echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

if [ "$USE_SSH" -eq 1 ]; then
    CHEATSHEET_URI=git@github.com:you-n-g/cheatsheets.git
    FARSIDE_URI=git@github.com:you-n-g/farside.git
else
    CHEATSHEET_URI=https://github.com/you-n-g/cheatsheets
fi

cd ~

if [ ! -e cheatsheets ]; then
    git clone --recursive "$CHEATSHEET_URI"
fi

if [ -n "$FARSIDE_URI" ] && [ ! -e farside ]; then
    git clone "$FARSIDE_URI"
fi
