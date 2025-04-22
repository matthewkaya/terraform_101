#!/bin/bash
# DNS Registration Script for RHEL 8.4 on GCP
# This script registers the server in DNS using nsupdate

set -e

# Variables - customize these
DNS_SERVER="ns1.example.com"
DNS_DOMAIN="example.com"
TTL=3600
KEY_FILE="/etc/nsupdate.key"
HOSTNAME=$(hostname -s)
FQDN=$(hostname -f)
IP_ADDRESS=$(ip route get 1 | awk '{print $7}')
REVERSE_IP=$(echo $IP_ADDRESS | awk -F. '{print $4"."$3"."$2"."$1}')
REVERSE_ZONE=$(echo $IP_ADDRESS | awk -F. '{print $3"."$2"."$1}')".in-addr.arpa"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root" 
   exit 1
fi

echo "======================================================"
echo "DNS Registration for RHEL 8.4 on GCP"
echo "======================================================"
echo "Hostname: $HOSTNAME"
echo "FQDN: $FQDN"
echo "IP Address: $IP_ADDRESS"
echo "DNS Server: $DNS_SERVER"
echo "======================================================"

# Install required packages
echo "[1/4] Installing required packages..."
dnf install -y bind-utils

# Create TSIG key for secure DNS updates if it doesn't exist
if [ ! -f "$KEY_FILE" ]; then
    echo "[2/4] Generating TSIG key for secure DNS updates..."
    dnssec-keygen -a HMAC-SHA256 -b 256 -n HOST -r /dev/urandom $DNS_DOMAIN > /dev/null 2>&1
    KEY_NAME=$(ls K${DNS_DOMAIN}*.key | head -1)
    KEY_VALUE=$(grep -v '^;' $KEY_NAME | cut -d ' ' -f 7-)
    
    cat > $KEY_FILE << EOF
key "$DNS_DOMAIN" {
    algorithm hmac-sha256;
    secret "$KEY_VALUE";
};
EOF
    
    chmod 600 $KEY_FILE
    
    echo "TSIG key generated and saved to $KEY_FILE"
    echo "IMPORTANT: Ensure this key is also configured on your DNS server"
else
    echo "[2/4] TSIG key file already exists at $KEY_FILE"
fi

# Create nsupdate commands for forward and reverse DNS entries
echo "[3/4] Creating DNS update commands..."

# Create the nsupdate input file
cat > /tmp/nsupdate_commands.txt << EOF
server $DNS_SERVER
key $DNS_DOMAIN $KEY_VALUE

# Remove any existing records for this host
update delete $HOSTNAME.$DNS_DOMAIN A
update delete $REVERSE_IP.$REVERSE_ZONE PTR

# Add new records
update add $HOSTNAME.$DNS_DOMAIN $TTL A $IP_ADDRESS
update add $REVERSE_IP.$REVERSE_ZONE $TTL PTR $HOSTNAME.$DNS_DOMAIN

send
EOF

# Execute nsupdate to register DNS
echo "[4/4] Executing DNS update..."
nsupdate -v -k $KEY_FILE /tmp/nsupdate_commands.txt

# Clean up temporary files
rm -f /tmp/nsupdate_commands.txt K${DNS_DOMAIN}*.key K${DNS_DOMAIN}*.private

echo "======================================================"
echo "DNS Registration Complete!"
echo "Forward record: $HOSTNAME.$DNS_DOMAIN -> $IP_ADDRESS"
echo "Reverse record: $IP_ADDRESS -> $HOSTNAME.$DNS_DOMAIN"
echo "======================================================"

# Verify DNS registration with dig and host commands
echo "Verifying DNS registration..."
echo "Forward lookup:"
dig @$DNS_SERVER $HOSTNAME.$DNS_DOMAIN A +short
echo "Reverse lookup:"
dig @$DNS_SERVER -x $IP_ADDRESS +short

echo "======================================================"