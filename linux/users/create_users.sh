#!/bin/bash

# create_users.sh - creates blue team users for the comp
# Usage: ./create_users.sh

# ===== Variables =====
users_to_create=("chronomancer" "anomaly")
# =====================

# verify_root ensures the script is run as root
#
# Takes no arguments
#
# Returns nothing
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root. Exiting..."
        exit 1
    fi
}

# give_sudo_group adds the user to either sudo or wheel depending on which exists
#
# Takes one argument:
#   $1 - The user to modify
#
# Returns nothing
give_sudo_group() {
    local user="$1"
    
    if getent group sudo > /dev/null 2>&1; then
        usermod -aG sudo "$user"
        echo "Added $user to sudo group"
    elif getent group wheel > /dev/null 2>&1; then
        usermod -aG wheel "$user"
        echo "Added $user to wheel group"
    else
        echo "No sudo or wheel group found; creating sudo group and adding $user"
        groupadd sudo
        usermod -aG sudo "$user"
    fi
}

# create_users creates the blue team users and adds them to the correct group
#
# Takes no arguments
#
# Returns nothing
create_users() {
    for user in "${users_to_create[@]}"; do
        useradd "$user" -m -s /bin/bash
        give_sudo_group "$user"
    done
}

# main entrypoint
main() {
    verify_root
    create_users
}

main
