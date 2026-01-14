tailscale_auth_key=

# Add Tailscale's package signing key and repository:
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install Tailscale
sudo apt-get update -y
sudo apt-get install tailscale -y

# Run Tailscale with Auth Key
sudo tailscale up --auth-key=$tailscale_auth_key
