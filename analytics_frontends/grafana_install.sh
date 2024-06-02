#!/bin/bash

#Install the signing key
wget -q -O /usr/share/keyrings/grafana.key https://apt.grafana.com/gpg.key

#Add repository to grafana.list
echo "deb [signed-by=/usr/share/keyrings/grafana.key] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list

#apt update and install (or update)
apt update && apt install grafana -y

#Start the server
systemctl enable --now grafana-server
