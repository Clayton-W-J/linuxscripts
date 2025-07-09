#!/bin/bash

# -------------------------------
# Netplan Configuration (Interactive)
# -------------------------------
echo ""
echo "=== Netplan Static IP Configuration ==="

read -rp "Enter network interface name (e.g., ens18): " NET_IFACE
read -rp "Enter desired static IP address with CIDR (e.g., 192.168.1.50/24): " STATIC_IP
read -rp "Enter default gateway (e.g., 192.168.1.1): " GATEWAY
read -rp "Enter DNS servers (comma-separated, e.g., 1.1.1.1,8.8.8.8): " DNS_RAW

IFS=',' read -ra DNS_ARRAY <<< "$DNS_RAW"

NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
TMP_NETPLAN="/tmp/netplan.$$"

echo "Backing up existing Netplan config to ${NETPLAN_FILE}.bak..."
sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"

echo "Generating new Netplan config..."

{
  echo "network:"
  echo "  version: 2"
  echo "  ethernets:"
  echo "    $NET_IFACE:"
  echo "      addresses:"
  echo "        - $STATIC_IP"
  echo "      nameservers:"
  echo "        addresses:"
  for dns in "${DNS_ARRAY[@]}"; do
    echo "          - $dns"
  done
  echo "        search: []"
  echo "      routes:"
  echo "        - to: default"
  echo "          via: $GATEWAY"
} > "$TMP_NETPLAN"

echo "Writing new Netplan config to $NETPLAN_FILE..."
sudo mv "$TMP_NETPLAN" "$NETPLAN_FILE"
echo "Applying Netplan changes..."
sudo netplan apply
