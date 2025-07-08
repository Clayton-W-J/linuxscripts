#!/bin/bash

# -------------------------------
# Default values
# -------------------------------
TEMPLATE_ID=10000              # ID of your template VM
DISK_STORAGE="vmdisk0"
DEFAULT_DISK_SIZE=32         # GB (number only for comparison)
DEFAULT_CORES=2
DEFAULT_MEMORY=2048          # MB
DEFAULT_BRIDGE="vmbr0"
DEFAULT_VLAN=1
DEFAULT_TAGS="mgmt"

# -------------------------------
# Manually defined variables
# -------------------------------
VMID=
NAME=""
DISK_SIZE=$DEFAULT_DISK_SIZE
CORES=$DEFAULT_CORES
MEMORY=$DEFAULT_MEMORY
BRIDGE=$DEFAULT_BRIDGE
VLAN=$DEFAULT_VLAN
TAGS=""

# -------------------------------
# Validation
# -------------------------------
if [[ -z "$VMID" || -z "$NAME" ]]; then
  echo "Usage: $0 <vmid> <name> [disk_size] [cores] [memory] [bridge] [vlan] [tags]"
  exit 1
fi

if ! [[ "$DISK_SIZE" =~ ^[0-9]+$ ]] || [ "$DISK_SIZE" -lt $DEFAULT_DISK_SIZE ]; then
  echo "Error: Disk size must be a number greater than or equal to ${DEFAULT_DISK_SIZE}"
  exit 1
fi

# -------------------------------
# Clone and configure VM
# -------------------------------
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

# Add cloud-init drive
qm set $VMID \
  --ide2 ${DISK_STORAGE}:cloudinit \
  --boot order=scsi0 \
  --serial0 socket \
  --vga serial0

# Start VM
qm start $VMID

echo "VM $VMID ($NAME) has been created and configured."
