#!/bin/bash

# This script automates the setup of a screenshot tool for Hyprland.
# It installs necessary packages, creates a screenshot script, makes it executable,
# and provides instructions for Hyprland configuration.

echo "--- Hyprland Screenshot Tool Setup Script ---"

# --- 1. Install Dependencies ---
echo "Checking and installing necessary packages (grim, slurp, swappy, wl-clipboard)..."

# Check if yay is installed
if ! command -v yay &> /dev/null; then
    echo "Error: 'yay' (AUR helper) is not found."
    echo "This script requires 'yay' to install packages on Arch Linux."
    echo "Please install 'yay' first, then re-run this script."
    exit 1
fi

# Install packages using yay
yay -S --noconfirm grim slurp swappy wl-clipboard
if [ $? -ne 0 ]; then
    echo "Error: Failed to install one or more packages. Please check your internet connection or yay configuration."
    exit 1
fi
echo "All necessary packages installed/updated."
echo ""

# --- 2. Create Screenshot Script ---
SCREENSHOT_SCRIPT_DIR="$HOME/.local/bin"
SCREENSHOT_SCRIPT_NAME="hypr-screenshot.sh"
FULL_SCRIPT_PATH="$SCREENSHOT_SCRIPT_DIR/$SCREENSHOT_SCRIPT_NAME"

echo "Creating screenshot script at '$FULL_SCRIPT_PATH'..."

# Ensure the directory exists
mkdir -p "$SCREENSHOT_SCRIPT_DIR"
if [ $? -ne 0 ]; then
    echo "Error: Failed to create directory '$SCREENSHOT_SCRIPT_DIR'. Exiting."
    exit 1
fi

# Write the screenshot script content
cat << 'EOF' > "$FULL_SCRIPT_PATH"
#!/bin/bash

# This script captures a screenshot, allows selection, editing,
# copying to clipboard, and saving to a file.

# Define screenshot directory
SCREENSHOT_DIR="$HOME/Pictures/Screenshots"
mkdir -p "$SCREENSHOT_DIR" # Ensure directory exists

TIMESTAMP=$(date +'%Y-%m-%d-%H%M%S')
FILENAME="screenshot_${TIMESTAMP}.png"
FULL_PATH="$SCREENSHOT_DIR/$FILENAME"

# Take screenshot of selected region using grim and slurp, pipe to swappy for editing
grim -g "$(slurp)" - | swappy -f - -o "$FULL_PATH"

# Check if swappy successfully saved the file
if [ -f "$FULL_PATH" ]; then
    echo "Screenshot saved to: $FULL_PATH"
    # Copy the screenshot to wl-clipboard (for Wayland)
    # The -f flag with swappy ensures it outputs to stdout if no -o is given,
    # but here we save it and then copy the file.
    # A more robust way might be to pipe grim output directly to wl-copy,
    # then pipe to swappy, but this method ensures the saved file is the edited one.
    # For simplicity and to ensure the edited image is copied:
    cat "$FULL_PATH" | wl-copy

    if [ $? -eq 0 ]; then
        echo "Screenshot copied to clipboard."
    else
        echo "Warning: Failed to copy screenshot to clipboard. Is wl-clipboard running?"
    fi
else
    echo "Screenshot capture or save cancelled/failed."
fi
EOF

# Make the script executable
chmod +x "$FULL_SCRIPT_PATH"
if [ $? -ne 0 ]; then
    echo "Error: Failed to make '$FULL_SCRIPT_PATH' executable. Exiting."
    exit 1
fi
echo "Screenshot script created and made executable."
echo ""

# --- 3. Hyprland Configuration Instructions ---
echo "--- Hyprland Configuration Steps (MANUAL ACTION REQUIRED) ---"
echo "Please manually add the following lines to your Hyprland configuration files."
echo "You will likely find these at '~/.config/hypr/hyprland.conf' or '~/.config/hypr/userprefs.conf'."
echo ""

echo "1. Add a keybinding to trigger the screenshot script:"
echo "   (You can use PrintScreen key, often 'PrtSc' or 'Print' on keyboards)"
echo "   --------------------------------------------------------------------------------"
echo '   bind = , PrintScreen, exec, ~/.local/bin/hypr-screenshot.sh'
echo "   --------------------------------------------------------------------------------"
echo ""

echo "2. Ensure 'wl-clipboard' is running on startup (add to ~/.config/hypr/userprefs.conf):"
echo "   This is crucial for copying screenshots to the clipboard."
echo "   --------------------------------------------------------------------------------"
echo '   exec-once = wl-paste -t text --watch clipboard_history & # For text clipboard history'
echo '   exec-once = wl-paste -t image --watch clipboard_history & # For image clipboard history'
echo "   # You might only need one of the above depending on your clipboard manager, or none if you use a dedicated one."
echo "   # The essential part for 'wl-copy' to work is that 'wl-paste' (or a compatible clipboard manager) is running."
echo "   # A simpler, more direct way to ensure wl-clipboard is ready for 'wl-copy' is often just:"
echo '   exec-once = wl-paste &'
echo "   --------------------------------------------------------------------------------"
echo ""

echo "After adding these lines, save your configuration files."
echo "Then, reload Hyprland by running 'hyprctl reload' in a terminal,"
echo "or log out and log back in for changes to take effect."
echo ""
echo "--- Setup Complete! ---"
echo "You can now test your screenshot tool using the configured keybinding."
