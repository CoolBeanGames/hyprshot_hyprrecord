#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if an unset variable is used.
# Print commands and their arguments as they are executed (for debugging).
# Removed set -eux for cleaner operation in production, but leaving for now if further issues arise.
# set -eux

# Directory to save screenshots
SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SAVE_DIR" || { notify-send "Screenshot Error" "Failed to create screenshot directory: $SAVE_DIR"; exit 1; }

# Generate a unique filename based on date and time
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FILEPATH="$SAVE_DIR/$FILENAME"

# Initialize status flags
ACTION_TAKEN=false
SCREENSHOT_ERROR=false
CANCELLED_BY_USER=false

# --- Region Screenshot Logic (Always executed) ---
REGION=$(slurp)
if [ -z "$REGION" ]; then
    CANCELLED_BY_USER=true
    notify-send "Screenshot Cancelled" "Region selection aborted."
else
    TEMP_GRIM_OUTPUT="/tmp/grim_temp_$(date +%s%N).png" # Temporary file for grim output
    grim -g "$REGION" "$TEMP_GRIM_OUTPUT"
    grim_exit_code=$?
    
    if [ $grim_exit_code -ne 0 ] || [ ! -f "$TEMP_GRIM_OUTPUT" ]; then
        SCREENSHOT_ERROR=true
        notify-send "Screenshot Error" "Grim failed to capture region."
    else
        # Pass the grim output to swappy for editing, and tell swappy to save to FILEPATH
        # swappy -f input_file -o output_file
        swappy -f "$TEMP_GRIM_OUTPUT" -o "$FILEPATH"
        swappy_exit_code=$?

        if [ $swappy_exit_code -eq 0 ] && [ -f "$FILEPATH" ] && [ -s "$FILEPATH" ]; then # Check if final file exists AND is not empty
            ACTION_TAKEN=true
        else
            # If swappy exited non-zero, or final file not created/empty, it's an error or cancellation within swappy
            if [ ! -f "$FILEPATH" ] || [ ! -s "$FILEPATH" ]; then 
                CANCELLED_BY_USER=true # Assume cancellation if file not created or is empty
                notify-send "Screenshot Cancelled" "Swappy editing aborted or failed to save."
            else
                SCREENSHOT_ERROR=true
                notify-send "Screenshot Error" "Swappy failed to process the screenshot."
            fi
        fi
    fi
    # Clean up temporary grim file regardless of swappy's outcome
    rm -f "$TEMP_GRIM_OUTPUT" 
fi

# Handle final notifications based on status flags
if $CANCELLED_BY_USER; then
    exit 0
elif $SCREENSHOT_ERROR; then
    # Notification already sent by specific error cases
    exit 1
elif $ACTION_TAKEN; then
    # Copy screenshot to Wayland clipboard
    wl-copy < "$FILEPATH"
    notify-send "Screenshot Taken" "Screenshot copied to clipboard and saved as $FILENAME"
    exit 0
else
    # Fallback for any unhandled scenario (should ideally not be reached)
    notify-send "Screenshot Error" "An unhandled scenario occurred during screenshot capture."
    exit 1
fi
