#!/bin/bash

# Directory to save screenshots
SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
mkdir -p "$SAVE_DIR" || { notify-send "Screenshot Error" "Failed to create screenshot directory: $SAVE_DIR"; exit 1; }

# Generate a unique filename based on date and time
FILENAME="screenshot_$(date +%Y%m%d_%H%M%S).png"
FILEPATH="$SAVE_DIR/$FILENAME"

# Options for Rofi menu
CHOICE=$(echo -e "region\nwindow\nmonitor\nfull screen\ncancel" | rofi -dmenu -p "Screenshot Type:")

# Initialize status flags
ACTION_TAKEN=false
SCREENSHOT_ERROR=false
CANCELLED_BY_USER=false

# --- DEBUGGING START ---
echo "$(date +'%Y-%m-%d %H:%M:%S') - Script started, CHOICE: \"$CHOICE\"" >> /tmp/screenshot_debug.log
# --- DEBUGGING END ---

case "$CHOICE" in
    "region")
        REGION=$(slurp)
        if [ -z "$REGION" ]; then
            CANCELLED_BY_USER=true
            echo "$(date +'%Y-%m-%S') - DEBUG: Region selection cancelled." >> /tmp/screenshot_debug.log
        else
            TEMP_SCREENSHOT="/tmp/grim_temp_$(date +%s%N).png"
            grim -g "$REGION" "$TEMP_SCREENSHOT"
            grim_exit_code=$?
            
            echo "$(date +'%Y-%m-%S') - DEBUG: grim (region) exited with code $grim_exit_code. Temp file exists: $([ -f "$TEMP_SCREENSHOT" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

            if [ $grim_exit_code -ne 0 ] || [ ! -f "$TEMP_SCREENSHOT" ]; then
                SCREENSHOT_ERROR=true
                notify-send "Screenshot Error" "Grim failed to capture region."
            else
                swappy -f "$TEMP_SCREENSHOT" "$FILEPATH"
                swappy_exit_code=$?

                echo "$(date +'%Y-%m-%S') - DEBUG: swappy (region) exited with code $swappy_exit_code. Final file exists: $([ -f "$FILEPATH" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

                if [ $swappy_exit_code -eq 0 ] && [ -f "$FILEPATH" ]; then
                    ACTION_TAKEN=true
                else
                    if [ ! -f "$FILEPATH" ]; then CANCELLED_BY_USER=true; fi
                    SCREENSHOT_ERROR=true
                fi
            fi
            rm -f "$TEMP_SCREENSHOT"
        fi
        ;;
    "window")
        WINDOW_GEOMETRY=$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
        if [ -z "$WINDOW_GEOMETRY" ]; then
            SCREENSHOT_ERROR=true
            notify-send "Screenshot Error" "Could not get active window geometry. Is a window focused?"
            echo "$(date +'%Y-%m-%S') - DEBUG: Window geometry empty." >> /tmp/screenshot_debug.log
        else
            TEMP_SCREENSHOT="/tmp/grim_temp_$(date +%s%N).png"
            grim -g "$WINDOW_GEOMETRY" "$TEMP_SCREENSHOT"
            grim_exit_code=$?

            echo "$(date +'%Y-%m-%S') - DEBUG: grim (window) exited with code $grim_exit_code. Temp file exists: $([ -f "$TEMP_SCREENSHOT" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

            if [ $grim_exit_code -ne 0 ] || [ ! -f "$TEMP_SCREENSHOT" ]; then
                SCREENSHOT_ERROR=true
                notify-send "Screenshot Error" "Grim failed to capture window."
                rm -f "$TEMP_SCREENSHOT"
            else
                swappy -f "$TEMP_SCREENSHOT" "$FILEPATH"
                swappy_exit_code=$?
                echo "$(date +'%Y-%m-%S') - DEBUG: swappy (window) exited with code $swappy_exit_code. Final file exists: $([ -f "$FILEPATH" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

                if [ $swappy_exit_code -eq 0 ] && [ -f "$FILEPATH" ]; then
                    ACTION_TAKEN=true
                else
                    if [ ! -f "$FILEPATH" ]; then CANCELLED_BY_USER=true; fi
                    SCREENSHOT_ERROR=true
                fi
                rm -f "$TEMP_SCREENSHOT"
            fi
        fi
        ;;
    "monitor")
        MONITOR_NAME=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        if [ -z "$MONITOR_NAME" ]; then
            SCREENSHOT_ERROR=true
            notify-send "Screenshot Error" "Could not determine focused monitor."
            echo "$(date +'%Y-%m-%S') - DEBUG: Monitor name empty." >> /tmp/screenshot_debug.log
        else
            TEMP_SCREENSHOT="/tmp/grim_temp_$(date +%s%N).png"
            grim -o "$MONITOR_NAME" "$TEMP_SCREENSHOT"
            grim_exit_code=$?

            echo "$(date +'%Y-%m-%S') - DEBUG: grim (monitor) exited with code $grim_exit_code. Temp file exists: $([ -f "$TEMP_SCREENSHOT" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

            if [ $grim_exit_code -ne 0 ] || [ ! -f "$TEMP_SCREENSHOT" ]; then
                SCREENSHOT_ERROR=true
                notify-send "Screenshot Error" "Grim failed to capture monitor."
                rm -f "$TEMP_SCREENSHOT"
            else
                swappy -f "$TEMP_SCREENSHOT" "$FILEPATH"
                swappy_exit_code=$?
                echo "$(date +'%Y-%m-%S') - DEBUG: swappy (monitor) exited with code $swappy_exit_code. Final file exists: $([ -f "$FILEPATH" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

                if [ $swappy_exit_code -eq 0 ] && [ -f "$FILEPATH" ]; then
                    ACTION_TAKEN=true
                else
                    if [ ! -f "$FILEPATH" ]; then CANCELLED_BY_USER=true; fi
                    SCREENSHOT_ERROR=true
                fi
                rm -f "$TEMP_SCREENSHOT"
            fi
        fi
        ;;
    "full screen")
        TEMP_SCREENSHOT="/tmp/grim_temp_$(date +%s%N).png"
        grim "$TEMP_SCREENSHOT"
        grim_exit_code=$?

        echo "$(date +'%Y-%m-%S') - DEBUG: grim (full screen) exited with code $grim_exit_code. Temp file exists: $([ -f "$TEMP_SCREENSHOT" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

        if [ $grim_exit_code -ne 0 ] || [ ! -f "$TEMP_SCREENSHOT" ]; then
            SCREENSHOT_ERROR=true
            notify-send "Screenshot Error" "Grim failed to capture full screen."
            rm -f "$TEMP_SCREENSHOT"
        else
            swappy -f "$TEMP_SCREENSHOT" "$FILEPATH"
            swappy_exit_code=$?
            echo "$(date +'%Y-%m-%S') - DEBUG: swappy (full screen) exited with code $swappy_exit_code. Final file exists: $([ -f "$FILEPATH" ] && echo "true" || echo "false")" >> /tmp/screenshot_debug.log

            if [ $swappy_exit_code -eq 0 ] && [ -f "$FILEPATH" ]; then
                ACTION_TAKEN=true
            else
                if [ ! -f "$FILEPATH" ]; then CANCELLED_BY_USER=true; fi
                SCREENSHOT_ERROR=true
            fi
            rm -f "$TEMP_SCREENSHOT"
        fi
        ;;
    "cancel")
        CANCELLED_BY_USER=true
        echo "$(date +'%Y-%m-%S') - DEBUG: Rofi 'cancel' selected." >> /tmp/screenshot_debug.log
        ;;
    *) # Handles Rofi cancellation (Esc/Ctrl+C) or invalid choice
        CANCELLED_BY_USER=true
        echo "$(date +'%Y-%m-%S') - DEBUG: Rofi cancelled or invalid choice." >> /tmp/screenshot_debug.log
        if [ -n "$CHOICE" ]; then # if CHOICE is not empty, means user typed something invalid
             notify-send "Screenshot Error" "Invalid Rofi selection: \"$CHOICE\"."
        fi
        ;;
esac

# --- DEBUGGING START ---
echo "$(date +'%Y-%m-%S') - DEBUG: Before final notification logic." >> /tmp/screenshot_debug.log
echo "$(date +'%Y-%m-%S') - DEBUG: CANCELLED_BY_USER=$CANCELLED_BY_USER, SCREENSHOT_ERROR=$SCREENSHOT_ERROR, ACTION_TAKEN=$ACTION_TAKEN" >> /tmp/screenshot_debug.log
# --- DEBUGGING END ---

# Handle final notifications based on status flags
if $CANCELLED_BY_USER; then
    exit 0
elif $SCREENSHOT_ERROR; then
    if ! $(notify-send --print-id "dummy" "dummy" >/dev/null 2>&1); then # This is a bit unreliable, better to use a specific flag
        notify-send "Screenshot Error" "Screenshot process failed unexpectedly."
    fi
    exit 1
elif $ACTION_TAKEN; then
    wl-copy < "$FILEPATH"
    notify-send "Screenshot Taken" "Screenshot copied to clipboard and saved as $FILENAME"
    exit 0
else
    notify-send "Screenshot Error" "An unhandled scenario occurred."
    exit 1
fi