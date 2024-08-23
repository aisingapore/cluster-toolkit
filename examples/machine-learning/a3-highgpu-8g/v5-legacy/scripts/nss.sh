#!/bin/bash

# Set environment variables
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-"Example Org"}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"adminpassword"}

# Update package lists
apt-get update

# Install debconf-utils
apt-get install -y debconf-utils

# Set DEBIAN_FRONTEND to noninteractive
export DEBIAN_FRONTEND=noninteractive

# Pre-configure LDAP settings
debconf-set-selections <<EOF
ldap-auth-config ldap-auth-config/binddn string cn=proxyuser,dc=example,dc=com
ldap-auth-config ldap-auth-config/bindpw password ${LDAP_ADMIN_PASSWORD}
ldap-auth-config ldap-auth-config/dblogin boolean false
ldap-auth-config ldap-auth-config/dbrootlogin boolean false
ldap-auth-config ldap-auth-config/ldapns/base-dn string dc=${LDAP_DOMAIN//./,dc=}
ldap-auth-config ldap-auth-config/ldapns/ldap-server string ldap://${LDAP_DOMAIN}
ldap-auth-config ldap-auth-config/ldapns/ldap_version select 3
ldap-auth-config ldap-auth-config/move-to-debconf boolean true
ldap-auth-config ldap-auth-config/override boolean true
ldap-auth-config ldap-auth-config/pam_password select md5
libnss-ldap libnss-ldap/binddn string cn=proxyuser,dc=example,dc=com
libnss-ldap libnss-ldap/bindpw password ${LDAP_ADMIN_PASSWORD}
libnss-ldap libnss-ldap/dblogin boolean false
libnss-ldap libnss-ldap/dbrootlogin boolean false
libnss-ldap libnss-ldap/nsswitch note
libnss-ldap libnss-ldap/rootbinddn string cn=admin,dc=${LDAP_DOMAIN//./,dc=}
libnss-ldap shared/ldapns/base-dn string dc=${LDAP_DOMAIN//./,dc=}
libnss-ldap shared/ldapns/ldap-server string ldap://${LDAP_DOMAIN}
libnss-ldap shared/ldapns/ldap_version select 3
EOF

# Install NSS LDAP packages
apt-get install -y libnss-ldap libpam-ldap ldap-utils nscd

# Configure NSS
sed -i 's/^passwd:.*/passwd:         compat ldap/' /etc/nsswitch.conf
sed -i 's/^group:.*/group:          compat ldap/' /etc/nsswitch.conf
sed -i 's/^shadow:.*/shadow:         compat ldap/' /etc/nsswitch.conf

# Configure PAM
pam-auth-update --package

# Restart NSS Cache Daemon
systemctl restart nscd

# Restart the Name Service Switch daemon
systemctl restart nslcd

echo "NSS LDAP installation and configuration completed."
