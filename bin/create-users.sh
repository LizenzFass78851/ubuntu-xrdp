#!/bin/bash

test -f /etc/users.list || exit 0

while read id username hash groups; do
        # Skip, if user already exists
        grep ^$username /etc/passwd && continue
        # Create group
        addgroup --gid $id $username
        # Create user
        if [ ! -d /home/$username ]; then mkdir /home/$username; fi
        useradd -u $id -s /bin/bash -g $username -d /home/$username -M $username
        # Set password
        echo "$username:$hash" | /usr/sbin/chpasswd -e
        # Add supplemental groups
        if [ $groups ]; then
                usermod -aG $groups $username
        fi
done < /etc/users.list
