#!/bin/bash

# This script sets global Git username and email,
# generates a new SSH key at the default location with no passphrase,
# and then displays the public SSH key.

echo "--- Git Global Configuration and SSH Key Setup Script ---"

# --- 1. Set Global Git Username ---
read -p "Enter your Git global username (e.g., John Doe): " GIT_USERNAME
if [ -z "$GIT_USERNAME" ]; then
    echo "Error: Git username cannot be empty. Exiting."
    exit 1
fi
git config --global user.name "$GIT_USERNAME"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set Git global username. Exiting."
    exit 1
fi
echo "Git global username set to: '$GIT_USERNAME'"

# --- 2. Set Global Git Email ---
read -p "Enter your Git global email (e.g., john.doe@example.com): " GIT_EMAIL
if [ -z "$GIT_EMAIL" ]; then
    echo "Error: Git email cannot be empty. Exiting."
    exit 1
fi
git config --global user.email "$GIT_EMAIL"
if [ $? -ne 0 ]; then
    echo "Error: Failed to set Git global email. Exiting."
    exit 1
fi
echo "Git global email set to: '$GIT_EMAIL'"
echo ""

# --- 3. Generate SSH Key ---
SSH_DIR="$HOME/.ssh"
SSH_KEY_PATH="$SSH_DIR/id_rsa"
SSH_PUB_KEY_PATH="$SSH_DIR/id_rsa.pub"

echo "Attempting to generate SSH key..."

# Check if .ssh directory exists, create if not
if [ ! -d "$SSH_DIR" ]; then
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR" # Set appropriate permissions
    echo "Created directory: $SSH_DIR"
fi

# Check if SSH key already exists
if [ -f "$SSH_KEY_PATH" ]; then
    read -p "Warning: An SSH key already exists at '$SSH_KEY_PATH'. Overwrite? (y/n): " OVERWRITE_CONFIRM
    if [[ ! "$OVERWRITE_CONFIRM" =~ ^[Yy]$ ]]; then
        echo "SSH key generation skipped. Existing key will be used."
        echo "--- Script Finished ---"
        # Skip to displaying the existing public key
        if [ -f "$SSH_PUB_KEY_PATH" ]; then
            echo ""
            echo "Your existing public SSH key ($SSH_PUB_KEY_PATH):"
            cat "$SSH_PUB_KEY_PATH"
            echo ""
            echo "Please add this key to your GitHub/GitLab account settings."
            exit 0
        else
            echo "Public key not found at '$SSH_PUB_KEY_PATH'. Please check your SSH setup."
            exit 1
        fi
    fi
    echo "Overwriting existing SSH key..."
fi

# Generate the SSH key (RSA, 4096 bits, no passphrase, default name)
ssh-keygen -t rsa -b 4096 -N "" -f "$SSH_KEY_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to generate SSH key. Exiting."
    exit 1
fi
echo "SSH key generated successfully at: '$SSH_KEY_PATH'"
echo ""

# --- 4. Display Public SSH Key ---
if [ -f "$SSH_PUB_KEY_PATH" ]; then
    echo "Your public SSH key ($SSH_PUB_KEY_PATH):"
    echo "--------------------------------------------------------------------------------"
    cat "$SSH_PUB_KEY_PATH"
    echo "--------------------------------------------------------------------------------"
    echo ""
    echo "Please copy the above public key (starting with 'ssh-rsa' and ending with your email)"
    echo "and add it to your GitHub, GitLab, or other Git hosting service SSH settings."
    echo "For GitHub, go to Settings -> SSH and GPG keys -> New SSH key."
else
    echo "Error: Public SSH key not found at '$SSH_PUB_KEY_PATH' after generation."
    echo "Please check your SSH setup manually."
    exit 1
fi

echo "Please go to github.com and set your ssh key in settings to complete authorization

echo "--- Script Finished ---"
