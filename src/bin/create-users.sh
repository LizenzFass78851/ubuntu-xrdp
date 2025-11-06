#!/bin/bash
set -e

# Check if users.list exists
if [ ! -f /etc/users.list ]; then
    echo "No users.list found. Skipping user creation."
    exit 0
fi

# Check if the file is empty
if [ ! -s /etc/users.list ]; then
    echo "users.list is empty. Skipping user creation."
    exit 0
fi

echo "Starting processing of users.list..."

# Set IFS for correct field separation
OLDIFS=$IFS
IFS=$'\n'

while IFS=$' \t' read -r id username hash groups || [ -n "$id" ]; do
    # Debug output of read values
    echo "Read values:"
    echo "ID: '$id'"
    echo "Username: '$username'"
    echo "Hash: '***'"
    echo "Groups: '$groups'"

    # Skip comments and empty lines
    [[ $id =~ ^#.*$ || -z $id ]] && continue
    
    echo "Processing user: $username"
    
    # Validate inputs
    validate_input() {
        local id=$1 username=$2 hash=$3
        if [[ ! $id =~ ^[0-9]+$ ]]; then
            echo "Invalid ID for user $username: $id"
            return 1
        fi
        if [[ ! $username =~ ^[a-z_][a-z0-9_-]*$ ]]; then
            echo "Invalid username: $username"
            return 1
        fi
        if [ -z "$hash" ]; then
            echo "No password hash provided for user $username"
            return 1
        fi
    }

    if ! validate_input "$id" "$username" "$hash"; then
        continue
    fi
    
    # Check if user already exists
    if getent passwd "$username" >/dev/null; then
        echo "User $username already exists, skipping..."
        continue
    fi

    # Create group
    addgroup --gid "$id" "$username" || {
        echo "Error creating group $username"
        continue
    }

    # Create home directory if not present
    if [ ! -d "/home/$username" ]; then
        mkdir -p "/home/$username"
    fi

    # Create user
    useradd -u "$id" -s /bin/bash -g "$username" -d "/home/$username" -M "$username" || {
        echo "Error creating user $username"
        continue
    }

    # Set password
    echo "$username:$hash" | /usr/sbin/chpasswd -e || {
        echo "Error setting password for $username"
        continue
    }

    # Set permissions for home directory
    chown -R "$username:$username" "/home/$username"
    chmod 750 "/home/$username"

    # Add additional groups one by one
    if [ -n "$groups" ]; then
        # Convert space-separated groups into comma-separated list
        IFS=' ' read -ra group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            echo "Adding user $username to group: $group"
            usermod -aG "$group" "$username" || {
                echo "Error adding group $group for $username"
                continue
            }
        done
    fi

    echo "User $username created successfully"
done < <(grep -v '^[[:space:]]*$' /etc/users.list)

# Reset IFS
IFS=$OLDIFS

echo "User creation completed"
exit 0
