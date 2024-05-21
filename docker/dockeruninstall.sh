#!/bin/bash

# Uninstall Docker Engine
sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

# Delete all images, container, and volumes
sudo rm -rf /var/lib/docker
sudo rm -rf /var/lib/containerd
