#!/bin/bash

# inventory.sh - takes inventory of the current machine
# Usage: ./inventory.sh

# ===== Colors =====
green='\e[32m'
yellow='\e[33m'
red='\e[31m'
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

# print_inventory prints the inventory of the current host
#
# Takes no arguments
#
# Prints the inventory
print_inventory() {
    format_print "Hostname" "IP Address"
    format_print "$host" "$ip_address"
}

# main entrypoint
main() {
    print_inventory
}

main
