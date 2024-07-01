#!/bin/bash

# Check if the script is run with a filename argument
if [ -z "$1" ]; then
    echo "Usage: $0 <name-of-text-file>"
    exit 1
fi

# Input file
input_file="$1"

# Log file
log_file="/var/log/user_management.log"
secure_passwords_file="/var/secure/user_passwords.csv"

# Create log file and secure passwords file
touch $log_file
mkdir -p /var/secure
touch $secure_passwords_file
chmod 600 $secure_passwords_file

# This function generates/ random password
generate_password() {
    tr -dc A-Za-z0-9 </dev/urandom | head -c 12
}

# Process each line in the input file
while IFS=";" read -r username groups; do
    # Trim whitespace from username and groups
    username=$(echo "$username" | xargs)
    groups=$(echo "$groups" | xargs)

    # Check if user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists." | tee -a $log_file
        continue
    fi

    # Create user and user's personal group
    user_group="$username"
    sudo groupadd $user_group
    sudo useradd -m -g $user_group -s /bin/bash $username
    echo "Created user $username with personal group $user_group." | tee -a $log_file

    # Add user to additional groups
    IFS=',' read -r -a additional_groups <<< "$groups"
    for group in "${additional_groups[@]}"; do
        sudo groupadd -f $group
        sudo usermod -aG $group $username
        echo "Added user $username to group $group." | tee -a $log_file
    done

    # Generate random password
    password=$(generate_password)
    echo "$username,$password" >> $secure_passwords_file
    echo "Set password for user $username." | tee -a $log_file

    # Set ownership and permissions for user's home directory
    sudo chown -R $username:$user_group /home/$username
    sudo chmod 700 /home/$username
    echo "Set ownership and permissions for /home/$username." | tee -a $log_file

    # Set password for user
    echo "$username:$password" | sudo chpasswd
done < "$input_file"

echo "User creation process completed." | tee -a $log_file
