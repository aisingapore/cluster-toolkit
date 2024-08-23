#!/bin/bash

# both client and server needs to be installed
set -e 

export DEBIAN_FRONTEND=noninteractive

apt install sssd-ldap ldap-utils sssd-tools -y


cat > /etc/sssd/sssd.conf <<EOF
[sssd]
config_file_version = 2
domains = example.com

[domain/example.com]
id_provider = ldap
ldap_uri = ldap://${LDAP_SERVER_IP}
cache_credentials = True
ldap_search_base = dc=example,dc=com
ldap_id_use_start_tls = false
ldap_tls_reqcert = never
ldap_auth_disable_tls_never_use_in_production = true
EOF

chmod 0600 /etc/sssd/sssd.conf

# verify if sss in nsswitch.conf

sed -i 's/compat/compat sss/g' /etc/nsswitch.conf

systemctl enable sssd
systemctl restart sssd
pam-auth-update --enable mkhomedir