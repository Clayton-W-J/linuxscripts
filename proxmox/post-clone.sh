#!/bin/bash

clear

# -------------------------------
# Hostname Configuration (Interactive)
# -------------------------------
echo ""
echo "=== Hostname Configuration ==="
read -rp "Enter the new hostname for this VM: " NEW_HOSTNAME

if [[ -z "$NEW_HOSTNAME" ]]; then
  echo "❌ Hostname cannot be empty. Exiting."
  exit 1
fi

echo "Setting hostname to $NEW_HOSTNAME..."
sudo hostnamectl set-hostname "$NEW_HOSTNAME"

# Update /etc/hosts
echo "Updating /etc/hosts file..."
if grep -q "127.0.1.1" /etc/hosts; then
  sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
else
  echo "127.0.1.1    $NEW_HOSTNAME" | sudo tee -a /etc/hosts > /dev/null
fi

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

# -------------------------------
# Disable cloud-init network config
# -------------------------------
echo "Disabling cloud-init network configuration..."

sudo mkdir -p /etc/cloud/cloud.cfg.d
echo "network: {config: disabled}" | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg > /dev/null

# -------------------------------
# Install and Start Tailscale (Interactive)
# -------------------------------

# Add Tailscale's package signing key and repository:
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt-get update -y
sudo apt-get install tailscale -y

# Run Tailscale with the NexusEdgeIT Auth Key
sudo tailscale up --auth-key=

# -------------------------------
# END Install and Start Tailscale
# -------------------------------

# -------------------------------
# Regenerate SSH Host Keys
# -------------------------------
echo ""
echo "Regenerating SSH host keys..."
sudo /usr/bin/ssh-keygen -A
sudo systemctl restart sshd

# -------------------------------
# END Regenerate SSH Host Keys
# -------------------------------

echo ""
echo "✅ Configuration complete!"
