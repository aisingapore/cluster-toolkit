#!/bin/bash

# Set variables
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-"Example Org"}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"adminpassword"}
LDAP_SERVER_IP=${LDAP_SERVER_IP:-"localhost"}

# Update package list
apt update

# Install LDAP client packages
apt install -y ldap-utils libnss-ldap libpam-ldap

# Configure LDAP client
debconf-set-selections <<EOF
ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=com
ldap-auth-config ldap-auth-config/bindpw password ${LDAP_ADMIN_PASSWORD}
ldap-auth-config ldap-auth-config/dblogin boolean false
ldap-auth-config ldap-auth-config/dbrootlogin boolean false
ldap-auth-config ldap-auth-config/ldapns/base-dn string dc=${LDAP_DOMAIN//./,dc=}
ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap://${LDAP_SERVER_IP}/
ldap-auth-config ldap-auth-config/ldapns/ldap_version select 3
ldap-auth-config ldap-auth-config/move-to-debconf boolean true
ldap-auth-config ldap-auth-config/override boolean true
ldap-auth-config ldap-auth-config/pam_password select md5
EOF

dpkg-reconfigure -f noninteractive ldap-auth-config

# Update NSS configuration
sed -i 's/compat/compat ldap/g' /etc/nsswitch.conf

# Update PAM configuration
pam-auth-update --enable ldap

echo "LDAP client installation and configuration completed."