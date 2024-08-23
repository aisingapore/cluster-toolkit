#!/bin/bash

# Environment variables (set these before running the script)
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-"Example Org"}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"adminpassword"}

if [ -z "${LDAP_SERVER_IP}" ]; then
  echo "LDAP_SERVER_IP is not set. Please set this variable before running the script."
  exit 1
fi
set -e
# Update and install required packages
apt-get update -y

DEBIAN_FRONTEND=noninteractive apt-get install -y apparmor ldap-utils ldapscripts

systemctl enable apparmor
systemctl start apparmor

echo "/etc/ldap/ldap.conf r," | tee -a /etc/apparmor.d/abstractions/ldapclient
echo "/etc/ssl/certs/ca-certificates.crt r," | tee -a /etc/apparmor.d/abstractions/ldapclient

# Create base.ldif file
cat > /tmp/base.ldif <<EOF
dn: ou=people,dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
objectClass: organizationalUnit
ou: people

dn: ou=groups,dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
objectClass: organizationalUnit
ou: groups
EOF

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
# Configure LDAP client
cat > /etc/ldap/ldap.conf <<EOF
BASE dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
URI ldap://${LDAP_SERVER_IP}
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
EOF

# Restart slapd
systemctl restart apparmor