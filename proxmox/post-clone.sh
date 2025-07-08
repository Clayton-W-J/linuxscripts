#/bin/bash

# This is a very sloppy script to wrap up my automated VM deployment on Proxmox

# -------------------------------
# Manually defined variables Start
# -------------------------------

NEW_HOSTNAME=""   # Set New Hostname

# -------------------------------
# Manually defined variables End
# -------------------------------

# Regenerate Host Keys due to template having them removed
sudo /usr/bin/ssh-keygen -A
sudo systemctl restart sshd

# Set the hostname
echo "Setting hostname to $NEW_HOSTNAME..."
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Update /etc/hosts
echo "Updating /etc/hosts file..."
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts

# -------------------------------
# Netplan Configuration (Interactive)
# -------------------------------

echo ""
echo "=== Netplan Static IP Configuration ==="

read -rp "Enter network interface name (e.g., ens18): " NET_IFACE
read -rp "Enter desired static IP address with CIDR (e.g., 192.168.1.50/24): " STATIC_IP
read -rp "Enter default gateway (e.g., 192.168.1.1): " GATEWAY
read -rp "Enter DNS servers (comma-separated, e.g., 1.1.1.1,8.8.8.8): " DNS

NETPLAN_FILE="/etc/netplan/01-netcfg.yaml"

echo "Backing up existing Netplan config to ${NETPLAN_FILE}.bak..."
sudo cp "$NETPLAN_FILE" "${NETPLAN_FILE}.bak"

echo "Writing new Netplan config..."
cat <<EOF | sudo tee "$NETPLAN_FILE" > /dev/null
network:
  version: 2
  ethernets:
    $NET_IFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP
      gateway4: $GATEWAY
      nameservers:
        addresses: [${DNS// /}]
EOF

echo "Applying Netplan changes..."
sudo netplan apply

echo "✅ Network configuration complete."
