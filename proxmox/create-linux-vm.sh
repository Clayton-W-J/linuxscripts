#!/bin/bash

# --------------------------------------------------------------------------
# Default Values
# --------------------------------------------------------------------------
TEMPLATE_ID=10000            # ID of your template VM
DISK_STORAGE="vmdisk0"       # Default Storage device used
DEFAULT_DISK_SIZE=32         # Default Storage Count in GB (number only for comparison)
DEFAULT_CORES=2              # Default Core Count
DEFAULT_MEMORY=2048          # Default Memory Amount in MB
DEFAULT_BRIDGE="vmbr0"       # Default Network Bridge
DEFAULT_VLAN=1               # Default VLAN
DEFAULT_TAGS="mgmt"          # Default VM Tag

# --------------------------------------------------------------------------
# Manually Defined VM Options (Interactive)
# --------------------------------------------------------------------------
VMID=
NAME=""
DISK_SIZE=$DEFAULT_DISK_SIZE
CORES=$DEFAULT_CORES
MEMORY=$DEFAULT_MEMORY
BRIDGE=$DEFAULT_BRIDGE
VLAN=$DEFAULT_VLAN
TAGS=""

# --------------------------------------------------------------------------
# Storage Validation
# --------------------------------------------------------------------------
if [[ -z "$VMID" || -z "$NAME" ]]; then
  echo "Usage: $0 <vmid> <name> [disk_size] [cores] [memory] [bridge] [vlan] [tags]"
  exit 1
fi

if ! [[ "$DISK_SIZE" =~ ^[0-9]+$ ]] || [ "$DISK_SIZE" -lt $DEFAULT_DISK_SIZE ]; then
  echo "Error: Disk size must be a number greater than or equal to ${DEFAULT_DISK_SIZE}"
  exit 1
fi

# --------------------------------------------------------------------------
# Clone and configure VM
# --------------------------------------------------------------------------
echo "Cloning VM template $TEMPLATE_ID to new VM $VMID ($NAME)..."

# Clone template
qm clone $TEMPLATE_ID $VMID --name $NAME --full yes

# Set VM options
qm set $VMID \
  --cores $CORES \
  --memory $MEMORY \
  --net0 virtio,bridge=${BRIDGE},tag=${VLAN} \
  --balloon 0 \
  --numa 1 \
  --onboot 1 \
  --agent enabled=1 \
  --tags $TAGS

# Resize disk
qm resize $VMID scsi0 ${DISK_SIZE}G

# --------------------------------------------------------------------------
# Firewall Configuration (Interactive)
# --------------------------------------------------------------------------

FIREWALL_FILE="/etc/pve/firewall/${VMID}.fw"

echo "Configuring firewall for VM $VMID..."

# Reset firewall config
cat > "$FIREWALL_FILE" <<EOF
[OPTIONS]

enable: 1
policy_in: DROP
policy_out: ACCEPT

[RULES]
# Default rule example:
IN ACCEPT -i net0 -source 10.10.10.0/24 -dest 10.10.10.18/32 -log nolog

# Custom rules can be added below:
EOF

# Example: Add custom firewall rules here if desired
# echo "IN ACCEPT -p tcp --dport 22 -log info" >> "$FIREWALL_FILE"

echo "Firewall configuration for VM $VMID applied."

# Start VM
qm start $VMID

echo "VM $VMID ($NAME) has been created and configured."
