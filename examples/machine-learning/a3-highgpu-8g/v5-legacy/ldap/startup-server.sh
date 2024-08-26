#!/bin/bash

# Environment variables (set these before running the script)
LDAP_DOMAIN=${LDAP_DOMAIN:-"example.com"}
LDAP_ORGANIZATION=${LDAP_ORGANIZATION:-"Example Org"}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-"adminpassword"}
LDAP_SERVER_IP=${LDAP_SERVER_IP:-"localhost"}
set -e
# Update and install required packages
apt-get update -y
DEBIAN_FRONTEND=noninteractive apt-get install -y slapd apparmor ldap-utils ldapscripts


systemctl enable apparmor
systemctl start apparmor
# Pre-seed slapd configuration
debconf-set-selections <<EOF
slapd slapd/internal/generated_adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/internal/adminpw password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password2 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/password1 password ${LDAP_ADMIN_PASSWORD}
slapd slapd/domain string ${LDAP_DOMAIN}
slapd shared/organization string ${LDAP_ORGANIZATION}
slapd slapd/backend string MDB
slapd slapd/purge_database boolean true
slapd slapd/move_old_database boolean true
slapd slapd/allow_ldap_v2 boolean false
slapd slapd/no_configuration boolean false
EOF

# Reconfigure slapd
dpkg-reconfigure -f noninteractive slapd

# Configure slapd to listen on specific IP
cat > /etc/ldap/slapd.d/cn=config/olcDatabase={1}mdb.ldif <<EOF
dn: olcDatabase={1}mdb
objectClass: olcDatabaseConfig
objectClass: olcMdbConfig
olcDatabase: {1}mdb
olcSuffix: dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
olcRootDN: cn=admin,dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
olcRootPW: ${LDAP_ADMIN_PASSWORD}
olcDbDirectory: /var/lib/ldap
olcDbIndex: objectClass eq
olcDbIndex: cn,uid eq
olcAccess: to * by dn.exact=gidNumber=0+uidNumber=0,cn=peercred,cn=external,cn=auth manage by * break
olcAccess: to attrs=userPassword by self write by anonymous auth by * none
olcAccess: to * by self read by users read by anonymous auth
EOF

echo "/etc/ldap/ldap.conf r," | tee -a /etc/apparmor.d/abstractions/ldapclient
echo "/etc/ssl/certs/ca-certificates.crt r," | tee -a /etc/apparmor.d/abstractions/ldapclient

# Add listen directive
echo "olcServerID: 1 ldap://${LDAP_SERVER_IP}:389" >> /etc/ldap/slapd.d/cn=config/olcDatabase={1}mdb.ldif

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
# Add base entries
ldapadd -x -D "cn=admin,dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')" -w ${LDAP_ADMIN_PASSWORD} -f /tmp/base.ldif

# Configure LDAP client
cat > /etc/ldap/ldap.conf <<EOF
BASE dc=$(echo ${LDAP_DOMAIN} | sed 's/\./,dc=/g')
URI ldap://${LDAP_SERVER_IP}
TLS_CACERT /etc/ssl/certs/ca-certificates.crt
EOF

# Restart slapd
systemctl restart slapd

# Set up SSSD
export DEBIAN_FRONTEND=noninteractive

apt install sssd-ldap ldap-utils sssd-tools -y

cat > /etc/sssd/sssd.conf <<EOF
[sssd]
config_file_version = 2
domains = example.com
services = nss, pam

[domain/example.com]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldap://172.16.0.42
cache_credentials = True
ldap_search_base = dc=example,dc=com
ldap_default_bind_dn = cn=admin,dc=example,dc=com
ldap_default_authtok_type = password
ldap_default_authtok = adminpassword
debug_level = 9
EOF

chmod 0600 /etc/sssd/sssd.conf

# verify if sss in nsswitch.conf

sed -i 's/compat/compat sss/g' /etc/nsswitch.conf

systemctl enable sssd
systemctl restart sssd
pam-auth-update --enable mkhomedir