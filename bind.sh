#!/bin/bash

# Interactive DNS Server Setup Script for AlmaLinux 9.5

# Pre-installation package setup for AlmaLinux 9.5
# Install EPEL repository (Extra Packages for Enterprise Linux)
sudo dnf install -y epel-release

# Install required packages
sudo dnf install -y \
    bind \
    bind-utils \
    firewalld \
    net-tools \
    policycoreutils-python-utils

# System Update
sudo dnf update -y

# Ensure firewalld is running
sudo systemctl enable firewalld
sudo systemctl start firewalld

# Function to handle user input with default values and validation
prompt_input() {
    local prompt="$1"
    local default="$2"
    local input

    while true; do
        read -p "$prompt [default: $default]: " input
        input=${input:-$default}
        
        if [[ -n "$input" ]]; then
            echo "$input"
            return 0
        else
            echo "Input cannot be empty. Please try again."
        fi
    done
}

# Collect interactive configuration inputs
# 1. Local domain name (e.g., mylocal.lab)
DOMAIN_NAME=$(prompt_input "Enter local domain name" "mylocal.lab")

# 2. Network prefix (first three octets of IP range)
NETWORK_PREFIX=$(prompt_input "Enter network prefix (e.g., 192.168.1)" "192.168.1")

# 3. Full network with subnet mask
DOMAIN_NETWORK=$(prompt_input "Enter full network with subnet mask (e.g., 192.168.1.0/24)" "${NETWORK_PREFIX}.0/24")

# Confirm configuration details
echo "Configuration Summary:"
echo "Domain: $DOMAIN_NAME"
echo "Network Prefix: $NETWORK_PREFIX"
echo "Network/Subnet: $DOMAIN_NETWORK"

# Allow user to cancel or confirm installation
read -p "Confirm configuration? (y/n): " conferma
if [[ "$conferma" != "y" && "$conferma" != "Y" ]]; then
    echo "Installation cancelled."
    exit 1
fi

# Primary BIND Configuration File
# Configures DNS server options, forwarders, and zone settings
sudo tee /etc/named.conf > /dev/null <<EOL
options {
    # Listen on localhost and local network
    listen-on port 53 { 127.0.0.1; ${NETWORK_PREFIX}.0/24; };
    listen-on-v6 port 53 { ::1; };
    
    # Directory for DNS-related files
    directory   "/var/named";
    
    # Diagnostic and statistics files
    dump-file   "/var/named/data/cache_dump.db";
    statistics-file "/var/named/data/named_stats.txt";
    memstatistics-file "/var/named/data/named_mem_stats.txt";
    recursing-file  "/var/named/data/named.recursing";
    secroots-file   "/var/named/data/named.secroots";
    
    # Enable DNS recursion
    recursion yes;
    allow-recursion { 127.0.0.1; localnets; };
    
    # Google DNS forwarders for external queries
    forwarders {
        8.8.8.8;
        8.8.4.4;
    };
    
    # Disable DNSSEC as requested
    dnssec-validation no;
    
    # Standard RFC1035 compliance settings
    auth-nxdomain no;
    listen-on-v6 { any; };
};

# Local Domain Forward Zone Configuration
zone "${DOMAIN_NAME}" IN {
    type master;
    file "/var/named/zones/db.${DOMAIN_NAME}";
    allow-update { none; };
};

# Local Network Reverse Zone Configuration
zone "${NETWORK_PREFIX}.in-addr.arpa" IN {
    type master;
    file "/var/named/zones/db.${NETWORK_PREFIX}.reverse";
    allow-update { none; };
};

# Removed duplicate zone definitions to prevent conflicts

# Root zone
zone "." IN {
    type hint;
    file "named.ca";
};

# Include other configurations carefully
include "/etc/named.root.key";
EOL

# Modify /etc/named.rfc1912.zones to prevent duplicate definitions
sudo tee /etc/named.rfc1912.zones > /dev/null <<EOL
# This file intentionally left minimal to prevent zone conflicts
# All custom zones are defined in named.conf
EOL

# Create directory for custom zone files
sudo mkdir -p /var/named/zones

# Forward Zone File (Domain Name Resolution)
# Maps domain names to IP addresses
sudo tee /var/named/zones/db.${DOMAIN_NAME} > /dev/null <<EOL
\$TTL 86400
@       IN SOA  ns1.${DOMAIN_NAME}. admin.${DOMAIN_NAME}. (
                        $(date +%Y%m%d)01 ; serial
                        3600       ; refresh
                        1800       ; retry
                        604800     ; expire
                        86400 )    ; minimum

        IN      NS      ns1.${DOMAIN_NAME}.

; DNS Server
ns1     IN      A       ${NETWORK_PREFIX}.10

; Example Internal Servers - Customize as needed
server1 IN      A       ${NETWORK_PREFIX}.11
server2 IN      A       ${NETWORK_PREFIX}.12  
storage IN      A       ${NETWORK_PREFIX}.13
backup  IN      A       ${NETWORK_PREFIX}.14

; Example Aliases
www     IN      CNAME   server1.${DOMAIN_NAME}.
mail    IN      CNAME   server2.${DOMAIN_NAME}.
EOL

# Reverse Zone File (IP to Domain Name Resolution)
# Maps IP addresses back to domain names
sudo tee /var/named/zones/db.${NETWORK_PREFIX}.reverse > /dev/null <<EOL
\$TTL 86400
@       IN SOA  ns1.${DOMAIN_NAME}. admin.${DOMAIN_NAME}. (
                        $(date +%Y%m%d)01 ; serial
                        3600       ; refresh
                        1800       ; retry
                        604800     ; expire
                        86400 )    ; minimum

        IN      NS      ns1.${DOMAIN_NAME}.

; Reverse Mapping - Customize as needed
10      IN      PTR     ns1.${DOMAIN_NAME}.
11      IN      PTR     server1.${DOMAIN_NAME}. 
12      IN      PTR     server2.${DOMAIN_NAME}.
13      IN      PTR     storage.${DOMAIN_NAME}.
14      IN      PTR     backup.${DOMAIN_NAME}.
EOL

# Set correct permissions for BIND configuration files
sudo chown -R named:named /var/named

# Validate Zone Configuration
# Check syntax of configuration and zone files
sudo named-checkconf /etc/named.conf
sudo named-checkzone ${DOMAIN_NAME} /var/named/zones/db.${DOMAIN_NAME}
sudo named-checkzone ${NETWORK_PREFIX}.in-addr.arpa /var/named/zones/db.${NETWORK_PREFIX}.reverse

# Firewall Configuration
# Open DNS ports and allow local network traffic
sudo firewall-cmd --permanent --add-port=53/tcp
sudo firewall-cmd --permanent --add-port=53/udp
sudo firewall-cmd --add-source=${DOMAIN_NETWORK} --permanent
sudo firewall-cmd --reload

# Local Resolver Configuration
# Set up local DNS resolution
sudo tee /etc/resolv.conf > /dev/null <<EOL
search ${DOMAIN_NAME}
nameserver 127.0.0.1
nameserver ${NETWORK_PREFIX}.10
nameserver 8.8.8.8
EOL

# Start and Enable BIND Service
sudo systemctl enable named
sudo systemctl restart named

# Verify Service Status
sudo systemctl status named

# Diagnostic Tests
# Verify forward and reverse DNS resolution
echo "DNS Local Configuration Tests:"
echo "1. Forward Resolution:"
dig @localhost server1.${DOMAIN_NAME}
echo "2. Reverse Resolution:"
dig -x ${NETWORK_PREFIX}.11

echo "BIND DNS Server installation and configuration completed!"
echo "Remember to customize server IP addresses if needed!"
