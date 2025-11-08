#!/bin/bash

# firewall_config.sh - Script to install and configure nftables
# Usage: ./firewall_config.sh
#   -l: run in headless mode

# ===== Colors =====
green='\e[32m'
yellow='\e[33m'
red='\e[31m'
reset='\e[0m'
# ==================

# ===== Config =====
script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
rules_file="$script_dir/default_rules.nft"
# ==================

# ===== Flag variables =====
headless=false
# ==========================

# parse_arguments parses command-line arguments and writes to variables
#
# Takes no arguments
#
# Returns nothing
parse_arguments() {
    while getopts l opt; do
        case $opt in
            l)
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

# detect_distro detects the linux distribution and prints the value
#
# Takes no arguments
#
# Prints the distro in lowercase
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "${ID,,}"
    else
        echo "unknown"
    fi
}

# install_nftables installs nftables based on os parsed from /etc/release
#
# Takes no arguments
#
# Returns nothing
install_nftables() {
    local distro="$(detect_distro)"

    case "$distro" in
        *ubuntu*|*debian*)
            apt-get update
            apt-get install -y nftables
        ;;
        *fedora*|*centos*|*rhel*|*rocky*|*almalinux*)
            if command -v dnf > /dev/null 2>&1; then
                dnf install -y nftables
            else
                yum install -y nftables
            fi
        ;;
        *arch*)
            pacman -Syu
            pacman -S --noconfirm nftables
        ;;
        *suse*|*opensuse*|*sles*)
            zypper install -y nftables
        ;;
        *)
            echo "Unsupported distribution: $distro"
        ;;
    esac
}

# enable_nftables enables and restarts the nftables service
#
# Takes no arguments
#
# Returns nothing
enable_nftables() {
    systemctl enable --now nftables
    systemctl restart nftables
}

# verify_nft_intallation checks that nftables is installed and installs it if not
#
# Takes no arguments
#
# Returns nothing
verify_nft_installation() {
    if ! command -v nft > /dev/null 2>&1; then
        install_nftables
        enable_nftables
    fi
}

# flush_ruleset flushes the current nftables ruleset and backs up existing ones
#
# Takes no arguments
#
# Returns nothing
flush_ruleset() {
    if nft list ruleset | grep -q 'table'; then
        echo -e "${yellow}Existing nftables rules detected. Backing them up to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi
    echo -e "${yellow}Flushing current nftables ruleset...${reset}"
    nft flush ruleset
}

# save_current_ruleset saves the in-memory nftables ruleset into the config file located at /etc/nftables.conf
#
# Takes no arguments
#
# Returns nothing
save_current_ruleset() {
    echo -e "${green}Saving current ruleset to /etc/nftables.conf...${reset}"
    nft list ruleset > /etc/nftables.conf
}

# restore_rules_from_backup restores the firewall rules from the backup located at /etc/nftables.backup
#
# Takes no arguments
#
# Returns 0 on success, 1 if file doesn't exist
restore_rules_from_backup() {
    if [ -f /etc/nftables.backup ]; then
        echo -e "${yellow}Restoring ruleset from /etc/nftables.backup...${reset}"
        nft flush ruleset
        nft -f /etc/nftables.backup
        echo -e "${green}Restored successfully.${reset}"
    else
        echo -e "${red}No backup file found at /etc/nftables.backup${reset}"
        return 1
    fi
}

# apply_default_ruleset applies a default nftables ruleset
#
# Takes no arguments
#
# Returns nothing
apply_default_ruleset() {

    if nft list ruleset | grep -q 'table'; then
        echo -e "${yellow}Warning: Existing nftables rules detected. Backing them up to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi
 
    if [ ! -f /etc/nftables.backup ]; then
        echo -e "${yellow}Warning: No backup file detected. Backing up nftables rules to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi   

    if [ "$headless" = true ]; then
        echo -e "${green}[HEADLESS] Applying default ruleset...${reset}"
        nft -f "$rules_file"
        save_current_ruleset
        return
    fi

    # diff returns 0 on success
    if diff -q /etc/nftables.backup <(tail -n +2 "$rules_file" | sed '/^\s*#/d'); then
        echo -e "${green}Current ruleset matches default ruleset.${reset}"
    else
        diff -u --label "current_ruleset" /etc/nftables.backup --label "default_ruleset" <(tail -n +2 "$rules_file")
        read -rp "Update ruleset to default configuration? (y/N): " update

        if [[ "${update,,}" != "y" ]]; then
            echo -e "${red}Restoring firewall ruleset to backup${reset}"
            restore_rules_from_backup
            exit 10
        fi

        echo -e "${green}Applying basic default nftables ruleset...${reset}"
        nft -f "$rules_file"
    fi

    # Dead man's switch
    echo -e "${green}[DMS] Press CTRL + C to persist the ruleset. Failure to do so will result in a rollback for lockout protection.${reset}"
    # Persist changes on SIGINT (Ctrl + C)
    trap 'echo -e "${green}[DMS] SIGINT received. Persisting ruleset...${reset}"; nft list ruleset > /etc/nftables.conf; return;' SIGINT
    # Wait 15 seconds for SIGINT
    sleep 15

    echo -e "${red}[DMS] No persist signal received. Rolling back firewall ruleset...${reset}"
    restore_rules_from_backup
    save_current_ruleset
    
}

# main entrypoint
main() {
    verify_root

    parse_arguments

    verify_nft_installation

    flush_ruleset

    apply_default_ruleset
}

main
