#!/bin/bash

# change_all_passwords.sh - Script to change the passwords of all users with a login shell
# Usage: ./change_all_passwords.sh

# ===== Config =====
# Users to exclude from password change
excluded_from_pw_change=("whiteteam" "grayteam" "blackteam" "datadog" "dd-dog" "dd-agent" "sync")
# ==================

# ===== Flag variables =====
headless=false
password_flag_value=""
# ==========================

# Read users with a login shell from /etc/passwd into $users_to_change array
mapfile -t users < <(awk -F: '$7 !~ /(nologin|false)/ {print $1}' /etc/passwd)

# parse_arguments parses command-line arguments and writes to variables
#
# Takes no arguments
#
# Returns nothing
parse_arguments() {
    while getopts p:h opt; do
        case $opt in
            h)
                headless=true
                ;;
            p)
                password_flag_value="$OPTARG"
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

# is_excluded determines if a user is excluded from the password change or not
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
        if is_excluded "$user" "${excluded_from_pw_change[@]}"; then
            echo "Skipping user: $user"
        else
            temp_users+=("$user")
        fi
    done

    printf '%s\n' "${temp_users[@]}"
}

# change_passwords handles changing the passwords for users
#
# Takes two arguments:
#   $1 - password to change to
#   $2 - array of users whose passwords should be changed
#
# Returns array of users who failed
change_passwords() {
    local password="$1"
    shift
    local users_to_change=("$@")
    for user in "${users_to_change[@]}"; do
        if is_excluded "$user" "${excluded_from_pw_change[@]}"; then
            echo "Skipping user: $user"
        else
            echo "$user:$password" | chpasswd
            if [ $? -eq 0 ]; then
                echo "Password changed for user: $user"
            else
                echo "Failed to change password for user: $user"
            fi
        fi
    done
}

# confirm_changes prompts the user for confirmation before changing passwords
#
# Takes one argument:
#   $1 - users whose passwords will be changed
#
# Returns nothing
#
# Exits on cancellation
confirm_changes() {
    local users_to_change=("$@")

    echo "The following users will have their passwords changed:"
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
    local password

    # Only run script as root
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Exiting..."
        exit 1
    fi

    parse_arguments

    if [ "$headless" = true ]; then
        if [ -z "$password_flag_value" ]; then
            echo "Headless mode requires a password passed with -p"
            exit 1
        fi
        password="$password_flag_value"
    else
        read -rsp "Enter the new password: " password
        echo
        read -rsp "Confirm the new password: " password_confirm
        echo

        if [ "$password" != "$password_confirm" ]; then
            echo "Passwords do not match! Exiting..."
            exit 1
        fi
    fi

    mapfile -t users_to_change < <(exclude_users "${users[@]}")

    if [ "$headless" = false ]; then
        confirm_changes "${users_to_change[@]}"
    fi
    
    change_passwords "$password" "${users_to_change[@]}"
}

main
