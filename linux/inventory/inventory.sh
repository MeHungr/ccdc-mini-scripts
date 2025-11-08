#!/bin/bash

# inventory.sh - takes inventory of the current machine
# Usage: ./inventory.sh

# ===== Colors =====
green='\e[32m'
yellow='\e[33m'
red='\e[31m'
bold='\e[1m'
reset='\e[0m'
# ==================

# ===== Variables =====
script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
outdir="$(dirname "$(dirname "$script_dir")")"
outfile="$outdir/output/inventory.txt"

host="$(hostname)"
defaultif="$(ip route | awk '/default/ { print $5 }')"
ip_address="$(ip a show "$defaultif" | awk '/inet/ { print $2 }' | head -n 1 | cut -d'/' -f1)"
# =====================

# Redirect all stdout to log file
exec > >(tee "$outfile") 2>&1

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

# find_unathorized_users prints all unauthorized users on the system
#
# Takes no arguments
#
# Prints the unauthorized users
find_unauthorized_users() {
    local authorized_users=("root" "whiteteam" "grayteam" "blackteam" "datadog" "dd-dog" "dd-agent" "sync" "drwho" "martymcfly" "arthurdent" "sambeckett" "loki" "riphunter" "theflash" "tonystark" "drstrange" "bartallen")
    local final_users=()
    mapfile -t users < <(awk -F: '$7 !~ /(nologin|false)/ {print $1}' /etc/passwd)
    for user in "${users[@]}"; do
        local found=false
        for u in "${authorized_users[@]}"; do
            if [ "$user" == "$u" ]; then
               found=true 
               break
            fi
        done
        if [ "$found" == false ]; then
            final_users+=("$user")
        fi
    done

    for user in "${final_users[@]}"; do
        printf "      - %s\n" "$(groups "$user")"
    done
}

# find_user_cron_jobs finds all user cron jobs
#
# Takes no arguments
#
# Prints any non empty crontabs
find_user_cron_jobs() {
    for user in $(cut -d: -f1 /etc/passwd); do
        if crontab -l -u "$user" > /dev/null 2>&1; then
            printf "%6s- $user has a non-empty crontab:\n%s\n" "" "$(crontab -l -u "$user" 2>/dev/null | sed 's/^/          /g')"
        fi
    done
}

# find_system_cron_jobs lists any system locations with cron jobs
#
# Takes no arguments
#
# Prints cron jobs or directories with files that have cron jobs
find_system_cron_jobs() {
    for location in "/etc/crontab" "/etc/cron.d" "/etc/cron.hourly" "/etc/cron.daily" "/etc/cron.weekly" "/etc/cron.monthly" "/var/spool/cron/crontabs" "/var/spool/cron"; do
        if [ -f "$location" ]; then
            printf "%6s- $location file contents:\n%s\n" "" "$(sed 's/^/          /g' "$location")"
        elif [ -d "$location" ]; then
            printf "%6s- $location directory contents:\n%s\n" "" "$(ls "$location" | sed 's/^/          /g')"
        fi
    done
}

# find_authorized_keys lists any authorized keys for each user with a home directory
#
# Takes no arguments
#
# Prints the authorized keys of each user
find_authorized_keys() {
    for user in $(ls -A /home); do
        keys_path="/home/$user/.ssh/authorized_keys"

        if [[ ! -e "$keys_path" || ! -s "$keys_path" ]]; then
            continue
        fi
        printf "%6s- $user authorized keys:\n%s\n" "" "$(sed 's/^/          /g' "$keys_path")"
    done
    if [[ -e "/root/.ssh/authorized_keys" || -s "/root/.ssh/authorized_keys" ]]; then
        printf "%6s- root authorized keys:\n%s\n" "" "$(sed 's/^/          /g' "/root/.ssh/authorized_keys")"
    fi
}

# format_print sets the printf format for the inventory printing
#
# Takes any number of arguments representing the fields to print:
#   $1 - Hostname
#   $2 - IP Address
#
# Prints the formatted string
format_print() {
    printf "%-25s%-16s\n" "$1" "$2"
}

# print_category prints an info category title
#
# Takes one argument:
#   $1 - category name
#
# Prints the formatted category name
print_category() {
    printf "${red}%4s%s${reset}:\n" "" "$1"
}

# print_inventory prints the inventory of the current host
#
# Takes no arguments
#
# Prints the inventory
print_inventory() {
    echo -e "${bold}================== Host ==================${reset}"
    format_print "Hostname" "IP Address"
    format_print "$host" "$ip_address"
    echo
    echo -e "${yellow}Info:${reset}"
    print_category "Unauthorized users"
    find_unauthorized_users
    print_category "User cron jobs"
    find_user_cron_jobs
    print_category "System cron jobs"
    find_system_cron_jobs
    print_category "Authorized keys"
    find_authorized_keys
    echo -e "${bold}==========================================${reset}"
}

# main entrypoint
main() {
    verify_root
    print_inventory
}

main
