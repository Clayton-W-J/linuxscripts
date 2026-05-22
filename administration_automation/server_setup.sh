#!/bin/bash
#
# Consolidated Server Setup Script
# Usage: ./server_setup.sh
#
# This script combines:
#   1. APT Update & Upgrade
#   2. Hostname Configuration
#   3. Timezone Configuration
#   4. QEMU Guest Agent Installation
#   5. Tailscale Installation
#   6. Ansible User Creation
#   7. SSH Hardening
#   8. Netplan Static IP Configuration
#
# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================
# Function to normalize input (uppercase + trim)
normalize_input() {
    echo "$1" | tr '[:lower:]' '[:upper:]' | xargs
}
# Function to prompt for yes/no with validation
prompt_yes_no() {
    local prompt_text="$1"
    local var_name="$2"
    while true; do
        echo "$prompt_text [y/n]"
        read -r "$var_name"
        local normalized=$(normalize_input "${!var_name}")
        if [[ -z "$normalized" ]]; then
            echo "🚫 No input provided."
            return 1
        elif [[ "$normalized" == "Y" ]]; then
            eval "$var_name=Y"
            return 0
        elif [[ "$normalized" == "N" ]]; then
            eval "$var_name=N"
            return 0
        else
            echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        fi
    done
}
# =============================================================================
# SCRIPT 1: APT UPDATE & UPGRADE
# =============================================================================
run_apt_update() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    clear
    echo "====================================================================="
    echo "                    APT Update & Upgrade                             "
    echo "====================================================================="
    echo ""
    # Step 1: Ask if user wants to proceed with update
    echo "Would you like to run 'apt update' and 'apt upgrade'? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 2: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. Update cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 Update cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 3: Run apt update
    echo ""
    echo "📦 Running apt update..."
    echo "====================================================================="
    if apt update; then
        echo ""
        echo "✅ apt update completed successfully!"
    else
        echo ""
        echo "❌ apt update failed."
        return 1
    fi
    # Step 4: Run apt upgrade
    echo ""
    echo "📦 Running apt upgrade..."
    echo "====================================================================="
    if apt upgrade -y; then
        echo ""
        echo "✅ apt upgrade completed successfully!"
    else
        echo ""
        echo "❌ apt upgrade failed."
        return 1
    fi
    # Step 5: Check for autoremovable packages
    echo ""
    echo "🔍 Checking for packages that can be autoremoved..."
    echo "====================================================================="
    AUTOREMOVE_PACKAGES=$(apt autoremove --dry-run 2>/dev/null | grep -E "^Remv" | awk '{print $2}' | sort)
    if [[ -z "$AUTOREMOVE_PACKAGES" ]]; then
        echo "ℹ️  No packages found that can be autoremoved."
    else
        echo ""
        echo "📦 The following packages can be autoremoved:"
        echo "---------------------------------------------------------------------"
        echo "$AUTOREMOVE_PACKAGES"
        echo "---------------------------------------------------------------------"
        echo ""
        local AUTOREMOVE_ANSWER=""
        prompt_yes_no "Would you like to remove these packages?" AUTOREMOVE_ANSWER
        if [[ "$AUTOREMOVE_ANSWER" == "Y" ]]; then
            echo ""
            echo "🗑️  Removing autoremovable packages..."
            echo "====================================================================="
            if apt autoremove -y; then
                echo ""
                echo "✅ Autoremove completed successfully!"
            else
                echo ""
                echo "❌ Autoremove failed."
                return 1
            fi
        elif [[ "$AUTOREMOVE_ANSWER" == "N" ]]; then
            echo ""
            echo "🚫 Autoremove cancelled by user. Keeping packages."
        fi
    fi
    echo ""
    echo "====================================================================="
    echo "                End of APT Update & Upgrade                          "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 2: HOSTNAME CONFIGURATION
# =============================================================================
run_hostname_config() {
    local NEW_HOSTNAME=""
    local ANSWER=""
    clear
    echo "====================================================================="
    echo "                    HOSTNAME Configuration                           "
    echo "====================================================================="
    echo ""
    # Step 1: Ask if user wants to proceed
    echo "Would you like to set a new hostname on this Linux machine? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 2: Validate response
    if [[ "$ANSWER" == "Y" ]]; then
        echo ""
        echo "Enter the new hostname:"
        read -r NEW_HOSTNAME
        # Basic validation
        if [[ -z "$NEW_HOSTNAME" ]]; then
            echo "❌ Error: Hostname cannot be empty."
            return 1
        fi
        # Validate hostname format (lowercase only, alphanumeric + hyphens)
        if ! [[ "$NEW_HOSTNAME" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?$ ]]; then
            echo "❌ Error: Invalid hostname format."
            echo "   Valid hostname should only contain lowercase letters, numbers and hyphens."
            return 1
        fi
        # Root check for hostname change
        if [[ $EUID -ne 0 ]]; then
            echo "❌ Error: Setting hostname requires root (use sudo)."
            return 1
        fi
        echo ""
        echo "⚙️  Changing hostname to: $NEW_HOSTNAME"
        # Step 3: Change the hostname
        if hostname "$NEW_HOSTNAME"; then
            echo "✅ Hostname changed successfully!"
        else
            echo "❌ Hostname could not be changed."
            return 1
        fi
        # Step 4: Backup /etc/hosts before modifying
        echo ""
        echo "📄 Updating /etc/hosts file..."
        BACKUP_FILE="/etc/hosts.bak.$(date +%Y%m%d%H%M%S)"
        cp /etc/hosts "$BACKUP_FILE"
        echo "   → Backup saved at: $BACKUP_FILE"
        # Step 5: Robust /etc/hosts cleanup and update
        echo "   🔍 Scanning for existing hostname entries in /etc/hosts..."
        OLD_HOSTNAME_1=$(grep -E "^127.0.0.1[[:space:]]+" /etc/hosts 2>/dev/null | awk '{print $2}' | grep -v "^localhost$" || true)
        OLD_HOSTNAME_2=$(grep -E "^127.0.1.1[[:space:]]+" /etc/hosts 2>/dev/null | awk '{print $2}' | grep -v "^localhost$" || true)
        ALL_OLD_HOSTNAMES=$(echo -e "${OLD_HOSTNAME_1}\n${OLD_HOSTNAME_2}" | grep -v '^$' | sort -u | tr '\n' '|' | sed 's/|$//')
        if [[ -n "$ALL_OLD_HOSTNAMES" ]]; then
            echo "   🗑️  Found old hostname(s): $ALL_OLD_HOSTNAMES"
            echo "   🗑️  Removing old hostname entries..."
            if [[ "$ALL_OLD_HOSTNAMES" == _"|"_ ]]; then
                sed -i -E "/^(127.0.0.1|127.0.1.1)[[:space:]]+($ALL_OLD_HOSTNAMES)/d" /etc/hosts
            else
                sed -i -E "/^(127.0.0.1|127.0.1.1)[[:space:]]+${ALL_OLD_HOSTNAMES}/d" /etc/hosts
            fi
        else
            echo "   ℹ️  No existing custom hostname entries found."
        fi
        # Remove any line with the new hostname
        sed -i -E "/^(127.0.0.1|127.0.1.1)[[:space:]]+.*${NEW_HOSTNAME}/d" /etc/hosts
        # Add new localhost entries
        if ! grep -q "^127.0.0.1[[:space:]]" /etc/hosts; then
            echo "127.0.0.1 localhost" >> /etc/hosts
        fi
        if grep -q "^127.0.1.1[[:space:]]" /etc/hosts; then
            sed -i "s/^127.0.1.1[[:space:]].*/127.0.1.1\t${NEW_HOSTNAME}/" /etc/hosts
        else
            echo "127.0.1.1 ${NEW_HOSTNAME}" >> /etc/hosts
        fi
        echo "   → Added/Updated entry: 127.0.1.1 ${NEW_HOSTNAME}"
        echo ""
        echo "📝 Current /etc/hosts:"
        cat /etc/hosts
        echo ""
        # Step 6: Update /etc/hostname file
        echo "📝 Updating /etc/hostname if it exists:"
        if [[ -f /etc/hostname ]]; then
            echo "$NEW_HOSTNAME" > /etc/hostname
            echo "✅ /etc/hostname updated with: $NEW_HOSTNAME"
        else
            echo "   ⚠️  /etc/hostname file not found."
        fi
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 Hostname change cancelled. No changes were made."
    else
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    echo ""
    echo "====================================================================="
    echo "                End of Hostname Configuration                        "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 3: TIMEZONE CONFIGURATION
# =============================================================================
run_timezone_config() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    local TARGET_TIMEZONE="America/Chicago"
    clear
    echo "====================================================================="
    echo "                   Timezone Configuration                           "
    echo "====================================================================="
    echo ""
    # Step 1: Check current timezone
    CURRENT_TIMEZONE=$(timedatectl show --property=Timezone --value 2>/dev/null || true)
    if [[ -z "$CURRENT_TIMEZONE" ]]; then
        echo "⚠️  Could not detect current timezone."
    else
        echo "ℹ️  Current timezone: $CURRENT_TIMEZONE"
    fi
    # Step 2: Check if timezone is already set to target
    if [[ "$CURRENT_TIMEZONE" == "$TARGET_TIMEZONE" ]]; then
        echo ""
        echo "✅ Timezone is already set to $TARGET_TIMEZONE."
        echo "🚫 No action needed. Exiting."
        echo "====================================================================="
        return 0
    fi
    # Step 3: Ask if user wants to proceed
    echo ""
    echo "Would you like to change the timezone to $TARGET_TIMEZONE? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 4: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. Timezone change cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 Timezone change cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 5: Set the timezone
    echo ""
    echo "⚙️  Setting timezone to $TARGET_TIMEZONE..."
    echo "====================================================================="
    if timedatectl set-timezone "$TARGET_TIMEZONE"; then
        echo ""
        echo "✅ Timezone changed successfully to $TARGET_TIMEZONE!"
    else
        echo ""
        echo "❌ Failed to set timezone."
        return 1
    fi
    # Step 6: Verify the change
    echo ""
    echo "🔍 Verifying timezone settings..."
    echo "====================================================================="
    timedatectl
    echo ""
    echo "====================================================================="
    echo "              End of Timezone Configuration                         "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 4: QEMU GUEST AGENT INSTALLATION
# =============================================================================
run_qemu_agent_install() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    local QEMU_GA_BINARY="/usr/sbin/qemu-ga"
    clear
    echo "====================================================================="
    echo "              QEMU Guest Agent Installation                          "
    echo "====================================================================="
    echo ""
    # Step 1: Check if qemu-guest-agent is already installed
    if [[ -x "$QEMU_GA_BINARY" ]]; then
        echo "ℹ️  qemu-guest-agent is already installed."
        echo "   Binary found at: $QEMU_GA_BINARY"
        echo ""
        echo "🔍 Checking service status..."
        echo "====================================================================="
        systemctl status qemu-guest-agent --no-pager || true
        echo ""
        echo "🚫 No action needed. Exiting."
        echo "====================================================================="
        return 0
    fi
    # Step 2: Ask if user wants to proceed
    echo "Would you like to install and enable qemu-guest-agent? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 3: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. Installation cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 Installation cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 4: Install qemu-guest-agent
    echo ""
    echo "📦 Installing qemu-guest-agent..."
    echo "====================================================================="
    if apt install qemu-guest-agent -y; then
        echo ""
        echo "✅ qemu-guest-agent installed successfully!"
    else
        echo ""
        echo "❌ Installation failed."
        return 1
    fi
    # Step 5: Start qemu-guest-agent
    echo ""
    echo "⚙️  Starting qemu-guest-agent..."
    echo "====================================================================="
    if systemctl start qemu-guest-agent; then
        echo ""
        echo "✅ qemu-guest-agent started successfully!"
    else
        echo ""
        echo "❌ Failed to start qemu-guest-agent."
        return 1
    fi
    # Step 6: Verify service status
    echo ""
    echo "🔍 Checking qemu-guest-agent service status..."
    echo "====================================================================="
    systemctl status qemu-guest-agent --no-pager
    echo ""
    echo "====================================================================="
    echo "           End of QEMU Guest Agent Installation                      "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 5: TAILSCALE INSTALLATION
# =============================================================================
run_tailscale_install() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    local TAILSCALE_AUTH_KEY=""
    clear
    echo "====================================================================="
    echo "                    Tailscale Installation                          "
    echo "====================================================================="
    echo ""
    # Step 1: Check if tailscale is already installed
    if command -v tailscale &> /dev/null; then
        echo "ℹ️  Tailscale is already installed."
        echo "   Binary found at: $(which tailscale)"
        echo ""
        echo "🔍 Checking tailscale status..."
        echo "====================================================================="
        tailscale status || true
        echo ""
        echo "🚫 No action needed. Exiting."
        echo "====================================================================="
        return 0
    fi
    # Step 2: Ask if user wants to proceed
    echo "Would you like to install Tailscale? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 3: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. Installation cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 Installation cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 4: Detect Ubuntu/Debian version for repository
    echo ""
    echo "🔍 Detecting system version..."
    echo "====================================================================="
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        VERSION_CODENAME="${VERSION_CODENAME:-jammy}"
    else
        echo "⚠️  Could not detect OS version. Using default 'jammy'."
        VERSION_CODENAME="jammy"
    fi
    echo "ℹ️  Detected version codename: $VERSION_CODENAME"
    # Step 5: Add Tailscale repository
    echo ""
    echo "📦 Adding Tailscale repository..."
    echo "====================================================================="
    # Add Tailscale's package signing key
    if curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null; then
        echo "✅ Added Tailscale package signing key."
    else
        echo "❌ Failed to add Tailscale package signing key."
        echo "   Trying with 'jammy' as fallback..."
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null || {
            echo "❌ Failed to add repository key."
            return 1
        }
        VERSION_CODENAME="jammy"
    fi
    # Add Tailscale repository
    if curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${VERSION_CODENAME}.tailscale-keyring.list" | tee /etc/apt/sources.list.d/tailscale.list >/dev/null; then
        echo "✅ Added Tailscale repository."
    else
        echo "⚠️  Trying with 'jammy' as fallback..."
        curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/jammy.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list >/dev/null || {
            echo "❌ Failed to add repository."
            return 1
        }
    fi
    # Step 6: Update package lists
    echo ""
    echo "📦 Updating package lists..."
    echo "====================================================================="
    if apt update; then
        echo "✅ Package lists updated."
    else
        echo "❌ Failed to update package lists."
        return 1
    fi
    # Step 7: Install Tailscale
    echo ""
    echo "📦 Installing Tailscale..."
    echo "====================================================================="
    if apt install tailscale -y; then
        echo ""
        echo "✅ Tailscale installed successfully!"
    else
        echo ""
        echo "❌ Installation failed."
        return 1
    fi
    # Step 8: Ask for auth key
    echo ""
    echo "🔑 Please enter your Tailscale auth key:"
    echo "   (You can get this from https://login.tailscale.com/admin/settings/keys)"
    read -r TAILSCALE_AUTH_KEY
    TAILSCALE_AUTH_KEY=$(echo "$TAILSCALE_AUTH_KEY" | xargs)
    if [[ -z "$TAILSCALE_AUTH_KEY" ]]; then
        echo ""
        echo "⚠️  No auth key provided. You can run 'tailscale up --auth-key=<key>' later."
        echo "====================================================================="
        return 0
    fi
    # Step 9: Run Tailscale with auth key
    echo ""
    echo "🚀 Starting Tailscale with auth key..."
    echo "====================================================================="
    if tailscale up --auth-key="$TAILSCALE_AUTH_KEY"; then
        echo ""
        echo "✅ Tailscale started successfully!"
    else
        echo ""
        echo "❌ Failed to start Tailscale."
        return 1
    fi
    # Step 10: Verify status
    echo ""
    echo "🔍 Checking Tailscale status..."
    echo "====================================================================="
    tailscale status
    echo ""
    echo "====================================================================="
    echo "               End of Tailscale Installation                        "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 6: ANSIBLE USER CREATION
# =============================================================================
run_ansible_user() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    local USERNAME="ansible"
    local SSH_PUBLIC_KEY=""
    local USER_PASSWORD=""
    clear
    echo "====================================================================="
    echo "                    Ansible User Creation                           "
    echo "====================================================================="
    echo ""
    # Step 1: Prompt for SSH public key
    echo "Please enter the SSH public key for the ansible user:"
    echo "   (Press Enter to cancel, or paste the key)"
    read -r SSH_PUBLIC_KEY
    SSH_PUBLIC_KEY=$(echo "$SSH_PUBLIC_KEY" | xargs)
    if [[ -z "$SSH_PUBLIC_KEY" ]]; then
        echo ""
        echo "❌ No SSH public key provided. Exiting."
        return 1
    fi
    # Validate key format
    if ! [[ "$SSH_PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
        echo "❌ Invalid SSH public key format."
        return 1
    fi
    echo "✅ SSH public key validated."
    echo ""
    # Step 2: Prompt for password
    echo "Please enter the password for the ansible user:"
    echo "   (Press Enter to cancel, or type 'random' for a generated password)"
    read -r -s USER_PASSWORD
    echo ""
    if [[ -z "$USER_PASSWORD" ]]; then
        echo "❌ No password provided. Exiting."
        return 1
    fi
    # Generate random password if requested
    if [[ "$USER_PASSWORD" == "random" ]]; then
        USER_PASSWORD=$(< /dev/urandom tr -dc 'A-Z' | head -c 3)$(< /dev/urandom tr -dc '@#$%&*' | head -c 3)$(< /dev/urandom tr -dc 'a-z0-9' | head -c 12 | shuf | tr -d '\n')
        USER_PASSWORD=$(echo "$USER_PASSWORD" | fold -w1 | shuf | tr -d '\n')
        echo "✅ Password generated."
    else
        # Confirm password
        echo "Please confirm the password:"
        read -r -s USER_PASSWORD_CONFIRM
        echo ""
        if [[ "$USER_PASSWORD" != "$USER_PASSWORD_CONFIRM" ]]; then
            echo "❌ Passwords do not match. Exiting."
            return 1
        fi
        echo "✅ Password confirmed."
    fi
    echo ""
    # Step 3: Ask if user wants to proceed
    echo "Would you like to create the ansible user? [y/n]"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 4: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. User creation cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 User creation cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 5: Check if user already exists
    if id "$USERNAME" &>/dev/null; then
        echo ""
        echo "ℹ️  User '$USERNAME' already exists."
        echo ""
        echo "Would you like to update the SSH key for user '$USERNAME'? [y/n]"
        read -r ANSWER
        ANSWER=$(normalize_input "$ANSWER")
        if [[ "$ANSWER" != "Y" ]]; then
            echo ""
            echo "🚫 SSH key update cancelled."
            return 0
        fi
        # Update SSH key
        USER_HOME="/home/$USERNAME"
        sudo -u "$USERNAME" mkdir -p "$USER_HOME/.ssh"
        echo "$SSH_PUBLIC_KEY" | sudo -u "$USERNAME" tee "$USER_HOME/.ssh/authorized_keys" > /dev/null
        sudo -u "$USERNAME" chmod 600 "$USER_HOME/.ssh/authorized_keys"
        sudo -u "$USERNAME" chmod 700 "$USER_HOME/.ssh"
        echo "✅ SSH key updated for user '$USERNAME'."
        echo "====================================================================="
        return 0
    fi
    # Step 6: Create the user
    echo ""
    echo "Creating user '$USERNAME'..."
    echo "====================================================================="
    if adduser --disabled-password --gecos "" "$USERNAME"; then
        echo "✅ User '$USERNAME' created."
    else
        echo "❌ Failed to create user '$USERNAME'."
        return 1
    fi
    # Step 7: Set the password
    echo ""
    echo "Setting password for user '$USERNAME'..."
    echo "====================================================================="
    if echo "$USERNAME:$USER_PASSWORD" | chpasswd; then
        echo "✅ Password set for user '$USERNAME'."
    else
        echo "❌ Failed to set password."
        return 1
    fi
    # Step 8: Configure sudoers file
    echo ""
    echo "Creating sudoers file for '$USERNAME'..."
    echo "====================================================================="
    SUDOERS_FILE="/etc/sudoers.d/$USERNAME"
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"
    echo "✅ Sudo permissions granted: $SUDOERS_FILE"
    # Step 9: Configure SSH key
    echo ""
    echo "Adding the public SSH key to /home/$USERNAME/.ssh/authorized_keys..."
    echo "====================================================================="
    USER_HOME="/home/$USERNAME"
    sudo -u "$USERNAME" mkdir -p "$USER_HOME/.ssh"
    echo "$SSH_PUBLIC_KEY" | sudo -u "$USERNAME" tee "$USER_HOME/.ssh/authorized_keys" > /dev/null
    sudo -u "$USERNAME" chmod 600 "$USER_HOME/.ssh/authorized_keys"
    sudo -u "$USERNAME" chmod 700 "$USER_HOME/.ssh"
    echo "✅ SSH key configured."
    echo ""
    echo "====================================================================="
    echo "               End of Ansible User Creation                         "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 7: SSH HARDENING
# =============================================================================
run_ssh_hardening() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    local ANSWER=""
    local SSH_CONFIG="/etc/ssh/sshd_config"
    local SSH_CONFIG_D="/etc/ssh/sshd_config.d"
    clear
    echo "====================================================================="
    echo "                      SSH Hardening                                  "
    echo "====================================================================="
    echo ""
    # Step 1: Show current SSH configuration
    echo "🔍 Current SSH configuration..."
    echo "====================================================================="
    echo "Port: $(grep -E '^Port ' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo '22')"
    echo "PermitRootLogin: $(grep -E '^PermitRootLogin ' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo 'prohibit-password')"
    echo "PasswordAuthentication: $(grep -E '^PasswordAuthentication ' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo 'yes')"
    echo "PubkeyAuthentication: $(grep -E '^PubkeyAuthentication ' "$SSH_CONFIG" 2>/dev/null | awk '{print $2}' || echo 'yes')"
    echo ""
    # Step 2: Ask if user wants to proceed
    echo "Would you like to harden the SSH configuration? [y/n]"
    echo "This will:"
    echo "   • Change port from 22 to 15370"
    echo "   • Disable root login"
    echo "   • Disable password authentication"
    echo "   • Enable public key authentication only"
    read -r ANSWER
    ANSWER=$(normalize_input "$ANSWER")
    # Step 3: Validate response
    if [[ -z "$ANSWER" ]]; then
        echo ""
        echo "🚫 No input provided. SSH hardening cancelled."
        return 0
    elif [[ "$ANSWER" == "N" ]]; then
        echo ""
        echo "🚫 SSH hardening cancelled by user. No changes were made."
        return 0
    elif [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "❌ Invalid input. Please answer 'y' for yes or 'n' for no."
        return 1
    fi
    # Step 4: Backup current SSH configuration
    echo ""
    echo "📄 Creating backup of SSH configuration..."
    echo "====================================================================="
    BACKUP_FILE="/etc/ssh/sshd_config.bak.$(date +%Y%m%d%H%M%S)"
    cp "$SSH_CONFIG" "$BACKUP_FILE"
    echo "✅ Backup saved at: $BACKUP_FILE"
    # Step 5: Apply SSH hardening
    echo ""
    echo "Applying SSH hardening..."
    echo "====================================================================="
    echo "   • Commenting out Include /etc/ssh/sshd_config.d/*.conf"
    sed -i "s/^Include \/etc\/ssh\/sshd_config.d\/\*.conf/#&/" "$SSH_CONFIG"
    echo "   • Changing port from 22 to 15370"
    sed -i "s/^#Port 22/Port 15370/" "$SSH_CONFIG"
    sed -i "s/^Port 22/Port 15370/" "$SSH_CONFIG"
    echo "   • Disabling root login"
    sed -i "s/^#PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"
    sed -i "s/^PermitRootLogin.*/PermitRootLogin no/" "$SSH_CONFIG"
    echo "   • Disabling password authentication"
    sed -i "s/^#PasswordAuthentication.*/PasswordAuthentication no/" "$SSH_CONFIG"
    sed -i "s/^PasswordAuthentication.*/PasswordAuthentication no/" "$SSH_CONFIG"
    echo "   • Enabling public key authentication"
    sed -i "s/^#PubkeyAuthentication.*/PubkeyAuthentication yes/" "$SSH_CONFIG"
    sed -i "s/^PubkeyAuthentication.*/PubkeyAuthentication yes/" "$SSH_CONFIG"
    echo "✅ SSH configuration updated."
    # Step 6: Validate SSH configuration
    echo ""
    echo "🔍 Validating SSH configuration..."
    echo "====================================================================="
    if sshd -t 2>/dev/null; then
        echo "✅ SSH configuration is valid."
    else
        echo "⚠️  SSH configuration test failed. Restoring backup..."
        cp "$BACKUP_FILE" "$SSH_CONFIG"
        echo "✅ Backup restored."
        return 1
    fi
    # Step 7: Restart SSH service
    echo ""
    echo "Restarting SSH service..."
    echo "====================================================================="
    if systemctl restart sshd; then
        echo "✅ SSH service restarted successfully."
    else
        echo "❌ Failed to restart SSH service."
        echo "   Restoring backup..."
        cp "$BACKUP_FILE" "$SSH_CONFIG"
        systemctl restart sshd
        return 1
    fi
    # Step 8: Display new configuration
    echo ""
    echo "📝 Updated SSH configuration:"
    echo "====================================================================="
    echo "Port: $(grep -E '^Port ' "$SSH_CONFIG" | awk '{print $2}')"
    echo "PermitRootLogin: $(grep -E '^PermitRootLogin ' "$SSH_CONFIG" | awk '{print $2}')"
    echo "PasswordAuthentication: $(grep -E '^PasswordAuthentication ' "$SSH_CONFIG" | awk '{print $2}')"
    echo "PubkeyAuthentication: $(grep -E '^PubkeyAuthentication ' "$SSH_CONFIG" | awk '{print $2}')"
    echo ""
    echo "====================================================================="
    echo "                  End of SSH Hardening                               "
    echo "====================================================================="
    return 0
}
# =============================================================================
# SCRIPT 8: NETPLAN STATIC IP CONFIGURATION
# =============================================================================
run_netplan_config() {
    if [[ $EUID -ne 0 ]]; then
        echo "❌ Error: This script must be run as root (use sudo)."
        return 1
    fi
    
    local NET_IFACE=""
    local STATIC_IP=""
    local GATEWAY=""
    local DNS_RAW=""
    local DNS_ARRAY=()
    local NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"
    local TMP_NETPLAN=""
    local ANSWER=""
    
    clear
    echo "====================================================================="
    echo "               Netplan Static IP Configuration                     "
    echo "====================================================================="
    echo ""
    
    # Step 1: Show current network interfaces
    echo "🔍 Available network interfaces:"
    echo "---------------------------------------------------------------------"
    ip -br addr show | grep -v "^lo" || ip link show | grep -v "^lo" | awk -F': ' '{print $2}'
    echo "---------------------------------------------------------------------"
    echo ""
    
    # Step 2: Prompt for network interface name
    echo "Please enter the network interface name (e.g., ens18):"
    read -r NET_IFACE
    NET_IFACE=$(echo "$NET_IFACE" | xargs)
    
    if [[ -z "$NET_IFACE" ]]; then
        echo "❌ Error: Network interface name cannot be empty."
        return 1
    fi
    
    # Validate interface exists (warning only)
    if ! ip link show "$NET_IFACE" &>/dev/null; then
        echo "⚠️  Warning: Interface '$NET_IFACE' does not exist. Continuing anyway..."
    fi
    
    # Step 3: Prompt for static IP
    echo ""
    echo "Please enter the desired static IP address with CIDR (e.g., 192.168.1.50/24):"
    read -r STATIC_IP
    STATIC_IP=$(echo "$STATIC_IP" | xargs)
    
    if [[ -z "$STATIC_IP" ]]; then
        echo "❌ Error: Static IP cannot be empty."
        return 1
    fi
    
    # Validate IP/CIDR format
    if ! [[ "$STATIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        echo "❌ Error: Invalid IP address format. Use CIDR notation (e.g., 192.168.1.50/24)."
        return 1
    fi
    
    # Step 4: Prompt for gateway
    echo ""
    echo "Please enter the default gateway (e.g., 192.168.1.1):"
    read -r GATEWAY
    GATEWAY=$(echo "$GATEWAY" | xargs)
    
    if [[ -z "$GATEWAY" ]]; then
        echo "❌ Error: Gateway cannot be empty."
        return 1
    fi
    
    # Validate gateway format
    if ! [[ "$GATEWAY" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "❌ Error: Invalid gateway format."
        return 1
    fi
    
    # Step 5: Prompt for DNS servers
    echo ""
    echo "Please enter DNS servers (comma-separated, e.g., 1.1.1.1,8.8.8.8):"
    read -r DNS_RAW
    DNS_RAW=$(echo "$DNS_RAW" | xargs)
    
    if [[ -z "$DNS_RAW" ]]; then
        echo "❌ Error: DNS servers cannot be empty."
        return 1
    fi
    
    # Parse DNS servers into array
    IFS=',' read -ra DNS_ARRAY <<< "$DNS_RAW"
    
    # Validate at least one DNS server
    if [[ ${#DNS_ARRAY[@]} -eq 0 ]]; then
        echo "❌ Error: At least one DNS server is required."
        return 1
    fi
    
    # Step 6: Show configuration summary
    echo ""
    echo "====================================================================="
    echo "                   Configuration Summary                           "
    echo "====================================================================="
    echo "  Interface:  $NET_IFACE"
    echo "  Static IP:   $STATIC_IP"
    echo "  Gateway:     $GATEWAY"
    echo "  DNS Servers: ${DNS_ARRAY[*]}"
    echo "====================================================================="
    echo ""
    
    # Step 7: Ask for confirmation
    prompt_yes_no "Would you like to apply this configuration?" ANSWER
    
    if [[ "$ANSWER" != "Y" ]]; then
        echo ""
        echo "🚫 Netplan configuration cancelled."
        return 0
    fi
    
    # Step 8: Backup existing Netplan configuration
    echo ""
    echo "📄 Backing up existing Netplan config..."
    echo "====================================================================="
    if [[ -f "$NETPLAN_FILE" ]]; then
        local BACKUP_FILE="${NETPLAN_FILE}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$NETPLAN_FILE" "$BACKUP_FILE"
        echo "✅ Backup saved at: $BACKUP_FILE"
    else
        echo "ℹ️  No existing Netplan config found, skipping backup."
    fi
    
    # Step 9: Generate new Netplan configuration
    echo ""
    echo "⚙️  Generating new Netplan configuration..."
    echo "====================================================================="
    
    TMP_NETPLAN="/tmp/netplan_$(date +%s).yaml"
    
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
    
    echo "📝 Generated Netplan configuration:"
    echo "---------------------------------------------------------------------"
    cat "$TMP_NETPLAN"
    echo "---------------------------------------------------------------------"
    
    # Step 10: Apply Netplan configuration
    echo ""
    echo "📦 Applying Netplan configuration..."
    echo "====================================================================="
    
    if ! mv "$TMP_NETPLAN" "$NETPLAN_FILE"; then
        echo "❌ Failed to write Netplan configuration file."
        return 1
    fi
    
    if ! netplan apply; then
        echo "❌ Failed to apply Netplan configuration."
        echo "   Restoring backup..."
        if [[ -f "${NETPLAN_FILE}.bak"* ]]; then
            cp "${NETPLAN_FILE}.bak"* "$NETPLAN_FILE"
            netplan apply
        fi
        return 1
    fi
    
    echo "✅ Netplan configuration applied successfully!"
    
    # Step 11: Disable cloud-init network configuration
    echo ""
    echo "⚙️  Disabling cloud-init network configuration..."
    echo "====================================================================="
    
    mkdir -p /etc/cloud/cloud.cfg.d
    echo "network: {config: disabled}" > /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    
    echo "✅ Cloud-init network configuration disabled."
    echo ""
    echo "====================================================================="
    echo "            End of Netplan Configuration                             "
    echo "====================================================================="
    return 0
}
# =============================================================================
# MAIN MENU
# =============================================================================
main_menu() {
    local CHOICE=""
    while true; do
        clear
        echo "====================================================================="
        echo "                  SERVER SETUP SCRIPT                               "
        echo "====================================================================="
        echo ""
        echo "Select an option:"
        echo ""
        echo "  1) APT Update & Upgrade"
        echo "  2) Hostname Configuration"
        echo "  3) Timezone Configuration"
        echo "  4) QEMU Guest Agent Installation"
        echo "  5) Tailscale Installation"
        echo "  6) Ansible User Creation"
        echo "  7) SSH Hardening"
        echo "  8) Netplan Static IP Configuration"
        echo ""
        echo "  A) Run All Tasks"
        echo "  Q) Quit"
        echo ""
        echo "====================================================================="
        echo -n "Enter your choice: "
        read -r CHOICE
        CHOICE=$(normalize_input "$CHOICE")
        case "$CHOICE" in
            1)
                run_apt_update
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            2)
                run_hostname_config
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            3)
                run_timezone_config
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            4)
                run_qemu_agent_install
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            5)
                run_tailscale_install
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            6)
                run_ansible_user
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            7)
                run_ssh_hardening
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            8)
                run_netplan_config
                echo ""
                echo "Press Enter to continue..."
                read -r
                ;;
            A)
                echo ""
                echo "Running all tasks..."
                echo "====================================================================="
                run_apt_update
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_hostname_config
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_timezone_config
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_qemu_agent_install
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_tailscale_install
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_ansible_user
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_ssh_hardening
                echo ""
                echo "Press Enter to continue to next task..."
                read -r
                run_netplan_config
                echo ""
                echo "Press Enter to return to menu..."
                read -r
                ;;
            Q)
                echo ""
                echo "Thank you for using Server Setup Script. Goodbye!"
                echo "====================================================================="
                exit 0
                ;;
            *)
                echo ""
                echo "❌ Invalid choice. Please try again."
                sleep 2
                ;;
        esac
    done
}
# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================
main_menu
