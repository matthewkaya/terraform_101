#!/bin/bash
# LDAP Authentication Setup Script for RHEL 8.4 on GCP
# This script configures LDAP authentication on a RHEL 8.4 server

set -e

# Variables - customize these
LDAP_SERVER="ldap.example.com"
LDAP_BASE_DN="dc=example,dc=com"
LDAP_BIND_DN="cn=admin,${LDAP_BASE_DN}"
LDAP_BIND_PASSWORD="secure_password"
LDAP_SSL_PORT="636"
HOSTNAME=$(hostname -f)
DOMAIN="example.com"
AD_SERVER="ad.example.com"
AD_ADMIN_USER="administrator"
AD_ADMIN_PASSWORD="secure_ad_password"
AD_GROUP_NAME="RHEL_Servers"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "======================================================"
echo "Setting up LDAP authentication for RHEL 8.4 on GCP"
echo "======================================================"

# Update system packages
echo "[1/7] Updating system packages..."
dnf update -y

# Install required packages
echo "[2/7] Installing required packages..."
dnf install -y sssd sssd-ldap authselect openldap-clients oddjob-mkhomedir

# Backup existing SSSD configuration if it exists
if [ -f /etc/sssd/sssd.conf ]; then
    echo "Backing up existing SSSD config..."
    cp /etc/sssd/sssd.conf /etc/sssd/sssd.conf.bak.$(date +%Y%m%d%H%M%S)
fi

# Configure SSSD for LDAP authentication
echo "[3/7] Configuring SSSD for LDAP authentication..."
cat > /etc/sssd/sssd.conf << EOF
[sssd]
services = nss, pam, sudo
config_file_version = 2
domains = default

[domain/default]
id_provider = ldap
auth_provider = ldap
ldap_uri = ldaps://${LDAP_SERVER}:${LDAP_SSL_PORT}
ldap_search_base = ${LDAP_BASE_DN}
ldap_id_use_start_tls = True
ldap_tls_reqcert = demand
cache_credentials = True
ldap_tls_cacert = /etc/openldap/certs/ca-bundle.crt
ldap_default_bind_dn = ${LDAP_BIND_DN}
ldap_default_authtok = ${LDAP_BIND_PASSWORD}
enumerate = False
access_provider = simple
simple_allow_groups = admins, users

[nss]
homedir_substring = /home

[pam]
offline_credentials_expiration = 2
offline_failed_login_attempts = 3
offline_failed_login_delay = 5
EOF

# Set proper permissions on SSSD config file
chmod 600 /etc/sssd/sssd.conf

# Configure authselect
echo "[4/7] Configuring authselect profile..."
authselect select sssd with-mkhomedir --force

# Enable and start SSSD service
echo "[5/7] Enabling and starting SSSD service..."
systemctl enable sssd
systemctl restart sssd

# Test LDAP connection
echo "[6/7] Testing LDAP connection..."
ldapsearch -H ldaps://${LDAP_SERVER}:${LDAP_SSL_PORT} -D "${LDAP_BIND_DN}" -w "${LDAP_BIND_PASSWORD}" -b "${LDAP_BASE_DN}" -s sub "(objectClass=*)" dn

echo "[7/7] LDAP Authentication setup complete!"
echo "======================================================"

echo "You may need to add firewall rules to allow LDAP traffic:"
echo "  firewall-cmd --permanent --add-service=ldap"
echo "  firewall-cmd --permanent --add-service=ldaps"
echo "  firewall-cmd --reload"
echo "======================================================"