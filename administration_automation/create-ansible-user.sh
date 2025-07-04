#!/bin/bash

# This is a standalone script to create an ansible user, set password, import public SSH key, and add the ansible sudoers file for Ansible automation purposes.
 
# Define the username and public SSH key
USERNAME="ansible"
SSH_PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCz/pPH+NpCcXOyMWX3+DCN9PomgE+XgA+6umxFh3iqchfsusfIdd/m5z6O/FVT5ocSswF+a8k4lnE5OvvY89yrrV6nqIFI0vkydYnF7XyGSS8xh5/7Zp/zkMcwccrk1QsYr3v5Du0y96uFurIWMomRovrEmhrwL2b7AFVeLB+l7GStP/kFpkgGubI/ZklwTLhnwTELdkD3JRfnW/zuJCW4OFeo3S7QVK7KyEQzxROPOxWUr1nqnBTk0Mm1g8OTV2wBMvaYnqYB8jek/Yp2tXx8H0wvf3r1Jfl+90hWXR6AlZNFr6s+Rtprd052Yq3JfatFHMfiiQwYzboZtdovA660Pobz/wReyrOm9nQSFwg4c1A1zNF49VK79bjOq8ue92cXtpwYCVP5YuUnFnuUAo3AmIoCCpPs0yoZ/kDyvVGB85kG6yOcyov020TyuaGjLvDHXe9ggiosZzPuVenV75SU33x3VpuOHhsroLt7zJRR9Vb7cQnVjugzXfPJYY+/epVvqQtzB5VEIdR3pVungA+lQLDBoFGrnxZyNQoKeYJTPUdQhACtqDAgYAR+qnmTqgmmpuvbxagLoaRx6FBRqNK3fDQqJQiNEnqjaJ6cDYi3WTac7RavPCIr9o+G1+Q+Rr8PueE7a6wX2XiJrJt8IbR2n6F85m2YrwirgL1DgJ17pQ== rsa-key-20241212"
# Add the user
echo "Creating user '$USERNAME'..."
sudo adduser --disabled-password --gecos "" "$USERNAME"
# Generate a secure password for the user
echo "Generating a secure password for the user '$USERNAME'..."
USER_PASSWORD=$(< /dev/urandom tr -dc 'A-Z' | head -c 3)$(< /dev/urandom tr -dc '@#$%&*' | head -c 3)$(< /dev/urandom tr -dc 'a-z0-9' | head -c 12 | shuf | tr -d '\n')
USER_PASSWORD=$(echo "$USER_PASSWORD" | fold -w1 | shuf | tr -d '\n') # Shuffle to randomize order
echo "$USERNAME:$USER_PASSWORD" | sudo chpasswd
# Creating ansible sudoers file and allowing all sudo commands to be run by Ansible user
# Define the sudoers file path
SUDOERS_FILE=/etc/sudoers.d/ansible
# Create the sudoers file with the required permissions
echo "Creating sudoers file for ansible user..."
sudo bash -c "echo 'ansible ALL=(ALL) NOPASSWD: ALL' > $SUDOERS_FILE"
# Set ownership to root
echo "Setting ownership to root..."
sudo chown root:root $SUDOERS_FILE
# Set correct permissions
echo "Setting permissions to 440..."
sudo chmod 440 $SUDOERS_FILE
echo "Sudoers configuration for 'ansible' user complete."

# Configure the SSH key
echo "Adding the public SSH key to /home/$USERNAME/.ssh/authorized_keys..."
USER_HOME="/home/$USERNAME"
sudo -u "$USERNAME" mkdir -p "$USER_HOME/.ssh"
echo "$SSH_PUBLIC_KEY" | sudo -u "$USERNAME" tee "$USER_HOME/.ssh/authorized_keys" > /dev/null
sudo -u "$USERNAME" chmod 600 "$USER_HOME/.ssh/authorized_keys"
sudo -u "$USERNAME" chmod 700 "$USER_HOME/.ssh"

 echo "- Ansible password: $USER_PASSWORD"
