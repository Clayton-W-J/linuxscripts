#!/bin/bash

# This script lays the foundation of the logic behind automating the act of deploying a VM on Proxmox

# -------------------------------
# User-defined variables
# -------------------------------
VMID=<name>                   # Must be unique on the node
NAME="some name"                # Replace with your desired name
TAGS="some tags"
ISO_STORAGE="local"        # Storage name where ISO is stored
ISO_FILE="iso/ubuntu-22.04.5-live-server-amd64.iso"  # Path relative to ISO_STORAGE
DISK_STORAGE="vmdisk0"     # Storage for VM disk and EFI
DISK_SIZE="<size>G"            # Replace as needed
CORES=2                    # Number of cores
MEMORY=2048                # Memory in MB
EFI_STORAGE="vmdisk0"
BRIDGE="vmbr0"             # Adjust based on your setup
VLAN_TAG=1               # Desired VLAN
NUM=${DISK_SIZE%G}         # Extract numeric portion of $DISK_SIZE
NUM_MINUS_ONE=$((NUM - 1)) # Subtract 1 from $NUM
NEW_DISK_SIZE="${NUM_MINUS_ONE}G" # New Disk Size

# -------------------------------
# VM Creation
# -------------------------------
echo "Creating VM $VMID ($NAME)..."

qm create $VMID \
  --name $NAME \
  --ostype l26 \
  --boot order=scsi0 \
  --scsihw virtio-scsi-single \
  --agent enabled=1 \
  --bios ovmf \
  --efidisk0 ${EFI_STORAGE}:1,efitype=4m,pre-enrolled-keys=1 \
  --scsi0 $DISK_STORAGE:1,backup=0,discard=on,size=$DISK_SIZE,ssd=1 \
  --cpu host \
  --numa 1 \
  --sockets 1 \
  --cores $CORES \
  --memory $MEMORY \
  --balloon 0 \
  --onboot 1 \
  --tags $TAGS

# Attach ISO
qm set $VMID \
  --ide2 ${ISO_STORAGE}:$ISO_FILE,media=cdrom

# Resize scsi0
qm resize $VMID scsi0 +$NEW_DISK_SIZE

# Set Network with VLAN
qm set $VMID \
  --net0 virtio,bridge=${BRIDGE},tag=${VLAN_TAG}

# Start the VM
qm start $VMID

# Done
echo "VM $VMID ($NAME) created with VLAN $VLAN_TAG on $BRIDGE."
