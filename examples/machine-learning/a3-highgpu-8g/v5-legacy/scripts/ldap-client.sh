#!/bin/bash

# Set variables
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-"Example Org"}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"adminpassword"}
LDAP_SERVER_IP=${LDAP_SERVER_IP:-"localhost"}

# Update package list
apt update

# Install LDAP client packages
apt install -y ldap-utils libnss-ldap libpam-ldap ldapscripts

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

# create ldapscripts
cat > /etc/ldapscripts/ldapscripts.conf <<EOF
SERVER="ldap://${LDAP_SERVER_IP}"
BINDDN="cn=admin,dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')"
BINDPWDFILE="/etc/ldapscripts/ldapscripts.passwd"
SUFFIX="dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')"

# Set the base for users and groups
USUFFIX="ou=people"
GSUFFIX="ou=groups"

# Set the UID and GID number ranges
UIDSTART="10000"
GIDSTART="10000"

# Enable UID/GID number management
GIDNUMBERFIELD="gidNumber"
UIDNUMBERFIELD="uidNumber"

LDAPSEARCHBIN="$(which ldapsearch)"
LDAPADDBIN="$(which ldapadd)"
LDAPDELETEBIN="$(which ldapdelete)"
LDAPMODIFYBIN="$(which ldapmodify)"
LDAPMODRDNBIN="$(which ldapmodrdn)"
LDAPPASSWDBIN="$(which ldappasswd)"
EOF

echo -n "${LDAP_ADMIN_PASSWORD}" > /etc/ldapscripts/ldapscripts.passwd
chmod 400 /etc/ldapscripts/ldapscripts.passwd

echo "LDAP client installation and configuration completed."