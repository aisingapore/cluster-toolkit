#!/bin/bash

# Run this script as root or with sudo

# Stop LDAP services
systemctl stop slapd
systemctl disable slapd

systemctl stop apparmor

# Remove LDAP configuration files and data directories
rm -rf /etc/ldap
rm -rf /var/lib/ldap

apt-get remove --purge apparmor slapd ldap-utils -y
# Clean up any remaining LDAP-related files
find /etc -name '*ldap*' -print0 | xargs -0 rm -rf
find /var -name '*ldap*' -print0 | xargs -0 rm -rf