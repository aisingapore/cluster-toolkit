#!/bin/bash

set -euo pipefail
# Get username from argument
username=$1
groups=$2
ssh_key=$3

# Add user group to ldap first
ldapaddgroup $username

# Add user with usergroup
ldapadduser $username $username

# Add user to supplementary groups
IFS=','
for group in $groups; do
  ldapaddusertogroup $username $group
done

# Set home directory path 
homedir="/home/$username"

# Create home directory if it doesn't exist
if [ ! -d "$homedir" ]; then
  mkdir -p "$homedir"
  # Copy skel files
  cp -R /etc/skel/. "$homedir"
  # Create .ssh directory
  mkdir "$homedir/.ssh"
  echo "${ssh_key}" > "$homedir/.ssh/authorized_keys"
  chmod -R 700 "$homedir"
  chown -R $username:$username "$homedir"
  chmod g+s $homedir
  echo "Created home directory for $username"
else
  echo "Home directory for $username already exists"
fi