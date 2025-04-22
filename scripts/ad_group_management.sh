#!/bin/bash
# Active Directory Group Management Script for RHEL 8.4 on GCP
# This script handles AD group creation and server registration

set -e

# Variables - customize these
AD_SERVER="ad.example.com"
AD_DOMAIN="example.com"
AD_ADMIN_USER="administrator"
AD_ADMIN_PASSWORD="secure_ad_password"
AD_GROUP_NAME="RHEL_Servers"
AD_GROUP_DESC="RHEL 8.4 Servers in GCP"
AD_OU="OU=Servers,OU=GCP,DC=example,DC=com"
HOSTNAME=$(hostname -s)
FQDN=$(hostname -f)
IP_ADDRESS=$(ip route get 1 | awk '{print $7}')

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "======================================================"
echo "Active Directory Group Management for RHEL 8.4 on GCP"
echo "======================================================"
echo "Hostname: $HOSTNAME"
echo "FQDN: $FQDN"
echo "IP Address: $IP_ADDRESS"
echo "AD Server: $AD_SERVER"
echo "AD Group: $AD_GROUP_NAME"
echo "======================================================"

# Install required packages
echo "[1/5] Installing required packages..."
dnf install -y realmd sssd sssd-tools oddjob oddjob-mkhomedir adcli samba-common-tools ldapscripts

# Create a temporary Kerberos ticket file
export KRB5CCNAME=/tmp/krb5cc_ad_admin

# Authenticate to AD
echo "[2/5] Authenticating to Active Directory..."
echo "$AD_ADMIN_PASSWORD" | kinit "${AD_ADMIN_USER}@${AD_DOMAIN^^}"

# Check if the group already exists, create if it doesn't
echo "[3/5] Checking if AD group exists..."
if ldapsearch -H ldap://$AD_SERVER -b "$AD_OU" -D "${AD_ADMIN_USER}@${AD_DOMAIN}" -w "$AD_ADMIN_PASSWORD" "(&(objectClass=group)(cn=$AD_GROUP_NAME))" | grep -q "cn: $AD_GROUP_NAME"; then
    echo "AD group $AD_GROUP_NAME already exists"
else
    echo "[3.1/5] Creating AD group $AD_GROUP_NAME..."
    
    # Create LDIF file for group creation
    cat > /tmp/create_group.ldif << EOF
dn: CN=$AD_GROUP_NAME,$AD_OU
objectClass: top
objectClass: group
cn: $AD_GROUP_NAME
description: $AD_GROUP_DESC
sAMAccountName: $AD_GROUP_NAME
groupType: -2147483646
EOF

    # Add the group using ldapadd
    ldapadd -H ldap://$AD_SERVER -D "${AD_ADMIN_USER}@${AD_DOMAIN}" -w "$AD_ADMIN_PASSWORD" -f /tmp/create_group.ldif
    
    # Clean up the temporary LDIF file
    rm -f /tmp/create_group.ldif
    
    echo "AD group $AD_GROUP_NAME created successfully"
fi

# Create a computer account for the server if it doesn't exist
echo "[4/5] Creating computer account in AD..."
if ! adcli info --domain=$AD_DOMAIN --host=$AD_SERVER --login-user="${AD_ADMIN_USER}" --login-password="$AD_ADMIN_PASSWORD" "$HOSTNAME" 2>/dev/null; then
    adcli create --domain=$AD_DOMAIN --host=$AD_SERVER --login-user="${AD_ADMIN_USER}" --login-password="$AD_ADMIN_PASSWORD" --computer-name="$HOSTNAME" --os-name="RHEL" --os-version="8.4" --host-fqdn="$FQDN" --domain-ou="$AD_OU"
else
    echo "Computer account for $HOSTNAME already exists in AD"
fi

# Add the computer account to the group
echo "[5/5] Adding server to AD group..."
COMPUTER_DN="CN=${HOSTNAME},${AD_OU}"
GROUP_DN="CN=${AD_GROUP_NAME},${AD_OU}"

# Create LDIF file for adding computer to group
cat > /tmp/add_computer_to_group.ldif << EOF
dn: $GROUP_DN
changetype: modify
add: member
member: $COMPUTER_DN
EOF

ldapmodify -H ldap://$AD_SERVER -D "${AD_ADMIN_USER}@${AD_DOMAIN}" -w "$AD_ADMIN_PASSWORD" -f /tmp/add_computer_to_group.ldif || echo "Computer may already be a member of the group"

# Clean up the temporary LDIF file
rm -f /tmp/add_computer_to_group.ldif

# Clean up Kerberos ticket
kdestroy

echo "======================================================"
echo "Active Directory Group Management Complete!"
echo "Computer Account: $HOSTNAME created/verified"
echo "AD Group: $AD_GROUP_NAME"
echo "Server added to group successfully"
echo "======================================================"