#!/bin/bash
root_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

echo "===== Creating inventory ====="

bash "$root_dir/linux/inventory/inventory.sh"
echo

echo "===== Creating users ====="

bash "$root_dir/linux/users/create_users.sh"
echo

echo "===== Changing passwords ====="

bash "$root_dir/linux/passwords/change_all_passwords.sh"
bash "$root_dir/linux/passwords/lock_users.sh"
echo

echo "===== Configuring firewall ====="

bash "$root_dir/linux/firewall/firewall_config.sh"
echo
