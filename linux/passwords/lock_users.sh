#!/bin/bash

# lock_users.sh - Script to lock users
# Usage: ./lock_users.sh
#   -p <password>: headless mode; requires a password

# ===== Config =====
# Users to exclude from lock
excluded_from_lock=("whiteteam" "grayteam" "blackteam" "datadog" "dd-dog" "dd-agent" "sync")
# ==================

# ===== Flag variables =====
headless=false
# ==========================

# Read users with a login shell from /etc/passwd into $users_to_change array
mapfile -t users < <(awk -F: '$7 !~ /(nologin|false)/ {print $1}' /etc/passwd)

# parse_arguments parses command-line arguments and writes to variables
#
# Takes no arguments
#
# Returns nothing
parse_arguments() {
    while getopts h opt; do
        case $opt in
            h)
                headless=true
                ;;
            ?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done
}

# is_excluded determines if a user is excluded from locking or not
#
# Takes two arguments:
#   $1 - user to check
#   $2 - array of users to check against
#
# Returns 0 if user is excluded, 1 otherwise
is_excluded() {
    local user="$1"
    shift

    local list=("$@")
    for excluded in "${list[@]}"; do
        if [[ "$user" == "$excluded" ]]; then
            return 0
        fi
    done
    return 1
}

# exclude_users returns an array of users to be modified after excluding users
#
# Takes one argument:
#   $1 - array of users to check against
#
# Returns the array of users to be modified
exclude_users() {
    local users=("$@")
    local temp_users=()
    
    for user in "${users[@]}"; do
        if ! is_excluded "$user" "${excluded_from_lock[@]}"; then
            temp_users+=("$user")
        fi
    done

    printf '%s\n' "${temp_users[@]}"
}

# lock_users handles locking users
#
# Takes two arguments:
#   $1 - array of users to be locked
#
# Returns array of users who failed
lock_users() {
    local users_to_change=("$@")
    for user in "${users_to_change[@]}"; do
        if is_excluded "$user" "${excluded_from_lock[@]}"; then
            echo "Skipping user: $user"
        else
            passwd -l "$user"
            if [ $? -eq 0 ]; then
                echo "Locked user: $user"
            else
                echo "Failed to lock user: $user"
            fi
        fi
    done
}

# confirm_changes prompts the user for confirmation before locking
#
# Takes one argument:
#   $1 - users who will be locked
#
# Returns nothing
#
# Exits on cancellation
confirm_changes() {
    local users_to_change=("$@")

    echo "The following users will be locked:"
    for user in "${users_to_change[@]}"; do
        echo "- $user"
    done

    read -rp "Do you want to proceed? (y/N): " confirm
    if [[ "${confirm,,}" != "y" ]]; then
        echo "Changes cancelled. Exiting..."
        exit 10
    fi
}

main() {
    # Only run script as root
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Exiting..."
        exit 1
    fi

    parse_arguments

    mapfile -t users_to_change < <(exclude_users "${users[@]}")

    if [ "$headless" = false ]; then
        confirm_changes "${users_to_change[@]}"
    fi
    
    lock_users "${users_to_change[@]}"
}

main
