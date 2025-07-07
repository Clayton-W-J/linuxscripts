#!/bin/bash

# This script lays the foundation of the logic behind automating the act of deploying a VM on Proxmox

# -------------------------------
# User-defined variables
# -------------------------------
VMID=101                   # Must be unique on the node
NAME="test"                # Replace with your desired name
ISO_STORAGE="local"        # Storage name where ISO is stored
ISO_FILE="/var/lib/vz/template/iso/"  # Path relative to ISO_STORAGE
DISK_STORAGE="vmdisk0"     # Storage for VM disk and EFI
DISK_SIZE="32G"            # Replace as needed
CORES=2                    # Number of cores
MEMORY=2048                # Memory in MB
EFI_STORAGE="vmdisk0"

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
  --machine q35 \
  --cpu host \
  --numa 1 \
  --sockets 1 \
  --cores $CORES \
  --memory $MEMORY \
  --balloon 0 \
  --onboot 1 \
  --tags mgmt

# Attach ISO
qm set $VMID \
  --ide2 ${ISO_STORAGE}:$ISO_FILE,media=cdrom

# Add Disk
qm set $VMID \
  --scsi0 ${DISK_STORAGE}:$DISK_SIZE,discard=on,ssd=1,backup=0

# Optional: Enable UEFI
qm set $VMID \
  --efidisk0 ${EFI_STORAGE}:1,efitype=4m,pre-enrolled-keys=1

# Done
echo "VM $VMID ($NAME) created."
