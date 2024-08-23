apt install gnutls-bin ssl-cert

certtool --generate-privkey --bits 4096 --outfile /etc/ssl/private/mycakey.pem


cat > /etc/ssl/ca.info <<EOF
cn = Example Company
ca
cert_signing_key
expiration_days = 3650
EOF

certtool --generate-self-signed \
--load-privkey /etc/ssl/private/mycakey.pem \
--template /etc/ssl/ca.info \
--outfile /usr/local/share/ca-certificates/mycacert.crt

update-ca-certificates

certtool --generate-privkey \
--bits 2048 \
--outfile /etc/ldap/ldap01_slapd_key.pem

cat > /etc/ldap/ldap01.info <<EOF
organization = Example Company
cn = ldap01.example.com
tls_www_server
encryption_key
signing_key
expiration_days = 3650
EOF

certtool --generate-certificate \
--load-privkey /etc/ldap/ldap01_slapd_key.pem \
--load-ca-certificate /etc/ssl/certs/mycacert.pem \
--load-ca-privkey /etc/ssl/private/mycakey.pem \
--template /etc/ssl/ldap01.info \
--outfile /etc/ldap/ldap01_slapd_cert.pem

chgrp openldap /etc/ldap/ldap01_slapd_key.pem
chmod 0640 /etc/ldap/ldap01_slapd_key.pem

cat > certinfo.ldif  <<EOF
dn: cn=config
add: olcTLSCACertificateFile
olcTLSCACertificateFile: /etc/ssl/certs/mycacert.pem
-
add: olcTLSCertificateFile
olcTLSCertificateFile: /etc/ldap/ldap01_slapd_cert.pem
-
add: olcTLSCertificateKeyFile
olcTLSCertificateKeyFile: /etc/ldap/ldap01_slapd_key.pem
EOF

ldapmodify -Y EXTERNAL -H ldapi:/// -f certinfo.ldif

sudo systemctl restart slapd

