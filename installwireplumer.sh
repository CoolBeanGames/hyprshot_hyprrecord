#!/bin/bash

# This script installs WirePlumber (the PipeWire session manager)
# and enables/starts its user service.

echo "--- Installing and Enabling WirePlumber ---"

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Error: 'yay' (AUR helper) is not found."
    echo "This script requires 'yay' to install packages on Arch Linux."
    echo "Please install 'yay' first, then re-run this script."
    exit 1
fi

# --- Install WirePlumber and resolve conflicts ---
# Instead of explicitly removing pipewire-media-session first,
# we install wireplumber along with common packages that depend on pipewire-session-manager.
# This allows yay/pacman to handle the replacement of pipewire-media-session with wireplumber.
echo "Attempting to install wireplumber and resolve potential conflicts..."
echo "You might be prompted to confirm replacing 'pipewire-media-session' with 'wireplumber'."

yay -S --noconfirm wireplumber pipewire-alsa pipewire-jack pipewire-pulse gst-plugin-pipewire xdg-desktop-portal-wlr
if [ $? -ne 0 ]; then
    echo "Error: Failed to install wireplumber or its dependencies. Please check the output above for details."
    echo "You may need to manually confirm the replacement of 'pipewire-media-session' if '--noconfirm' is problematic."
    exit 1
fi
echo "WirePlumber and related PipeWire components installed/updated successfully."
echo ""

echo "Enabling and starting wireplumber user service..."
systemctl --user enable --now wireplumber.service
if [ $? -ne 0 ]; then
    echo "Error: Failed to enable or start wireplumber.service. Please check systemd logs."
    exit 1
fi
echo "WirePlumber service enabled and started."
echo ""

echo "--- WirePlumber Setup Complete ---"
echo "It is highly recommended to reboot your system or at least log out and back in"
echo "to ensure all PipeWire components (including WirePlumber) are initialized correctly."
echo "After rebooting/relogging, you can verify its status with: systemctl --user status wireplumber"
