# almalinux-bind-dns-setup
Interactive BIND DNS Server Setup Script for AlmaLinux 9.5

# Introduction

This script automates the installation and configuration of a local DNS server using BIND on AlmaLinux 9.5. It includes steps for pre-installation, package setup, firewall configuration, and zone file creation for forward and reverse DNS resolution. The script also supports user interaction to customize domain and network settings.


# Features

- Interactive prompts for domain name, network prefix, and subnet mask.

- Automatic installation of necessary packages (e.g., BIND, firewalld).

- Creation of configuration files for BIND, including:
named.conf
Forward zone file
Reverse zone file

- Automatic setup of firewall rules for DNS traffic.

- Local resolver configuration for testing.

- Syntax checks for configuration and zone files.

- Built-in diagnostic tests for DNS resolution.


# Requirements

 -AlmaLinux 9.5

- Root privileges

- Vm with 2core, 2gb ram, 32gb hdd/ssd


## How to Use

1. **Update the system & clone the Repository**  
   Download the script to your system or clone the repository:
   ```bash
   apt update && apt upgrade

   dnf install git
   
   git clone https://github.com/eugeniogiusti/almalinux-bind-dns-setup.git
   
   cd almalinux-bind-dns-setup


2. Grant Execution Permissions
Give the script executable permissions:
   ```bash
   chmod +x bind.sh


3. Run the Script &
Switch to the root user if you don't want to enter the password during the process:
   ```bash
   sudo su
   ./bind.sh


# Customization

# Adjusting Zone Files

- You can edit the zone files located in /var/named/zones/ to add or modify records:

- Forward zone file: /var/named/zones/db.<domain>

- Reverse zone file: /var/named/zones/db.<network>.reverse

# Adding New Records

- Add A records for new hosts in the forward zone file.

- Add PTR records for new hosts in the reverse zone file.

- Increment the serial number in the SOA record after making changes.

Restart BIND After Changes

```bash
sudo systemctl restart named


# Troubleshooting

BIND Service Fails to Start:

- Check the syntax of named.conf:
  ```bash
sudo named-checkconf /etc/named.conf


- Verify zone file syntax:
   ```bash
sudo named-checkzone <domain> /var/named/zones/db.<domain>



DNS Resolution Issues:

- Ensure the firewall is properly configured:
   ```bash
sudo firewall-cmd --list-all

- Check /etc/resolv.conf for correct nameserver entries


