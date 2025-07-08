#!/bin/bash

# Directory to save recordings
RECORD_DIR="$HOME/Videos/Recordings"
mkdir -p "$RECORD_DIR"

# Generate a unique filename
FILENAME="recording_$(date +%Y%m%d_%H%M%S).mp4"
FILEPATH="$RECORD_DIR/$FILENAME"

# Check if wf-recorder is already running
if pgrep -x "wf-recorder" > /dev/null; then
    notify-send "Screen Recording" "Stopping recording..."
    pkill -INT wf-recorder # Send interrupt signal to stop gracefully
    sleep 1 # Give it a moment to stop
    notify-send "Recording Saved!" "Recording finished and saved to $FILEPATH"
    exit 0
fi

# If not running, prompt to start recording
CHOICE=$(echo -e "region\nmonitor\ncancel" | rofi -dmenu -p "Record Screen:")

case "$CHOICE" in
    "region")
        notify-send "Screen Recording" "Select region to record..."
        wf-recorder -g "$(slurp)" -f "$FILEPATH" & # Record region in background
        ;;
    "monitor")
        notify-send "Screen Recording" "Recording focused monitor..."
        MONITOR_NAME=$(hyprctl monitors | grep "focused: yes" | awk '{print $2}')
        wf-recorder -o "$MONITOR_NAME" -f "$FILEPATH" & # Record focused monitor in background
        ;;
    "cancel")
        notify-send "Screen Recording Aborted" "No recording started."
        exit 1
        ;;
    *)
        notify-send "Screen Recording Error" "Invalid selection in Rofi menu."
        exit 1
        ;;
esac

# Notify if recording started successfully
if [ $? -eq 0 ]; then
    notify-send "Screen Recording Started!" "Recording to $FILENAME. Press this hotkey again to stop."
fi