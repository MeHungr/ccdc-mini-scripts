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

# verify_nft_intallation checks that nftables is installed and installs it if not
#
# Takes no arguments
#
# Returns nothing
verify_nft_installation() {
    if ! command -v nft > /dev/null 2>&1; then
        install_nftables
    fi
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

# apply_default_ruleset applies a default nftables ruleset
apply_default_ruleset() {

    if nft list ruleset | grep -q 'table'; then
        echo -e "${yellow}Warning: Existing nftables rules detected. Backing them up to /etc/nftables.backup${reset}"
        nft list ruleset > /etc/nftables.backup
    fi
    
    if [ "$headless" = true ]; then
        echo -e "${green}[HEADLESS] Applying default ruleset...${reset}"
        nft -f "$rules_file"
    fi
}
