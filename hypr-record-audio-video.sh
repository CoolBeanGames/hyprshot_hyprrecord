#!/bin/bash

# --- Configuration ---
RECORD_VIDEO_DIR="$HOME/Videos/Recordings"
RECORD_AUDIO_DIR="$HOME/.cache/recordings_audio" # Temporary directory for audio
FINAL_RECORD_DIR="$HOME/Videos/Recordings"       # Final destination for merged file

AUDIO_SOURCE="@DEFAULT_SOURCE@" # Often reliable for default system audio input
                                # If you need a specific mic/source, run 'pactl list sources'
                                # and replace "@DEFAULT_SOURCE@" with its 'Name:'

# --- Ensure Directories Exist ---
mkdir -p "$RECORD_VIDEO_DIR" "$RECORD_AUDIO_DIR" "$FINAL_RECORD_DIR"

# --- Define Global PID File ---
# This file will hold the PIDs and temporary file paths of the currently active recording
GLOBAL_PID_FILE="/tmp/hypr_recorder_active.pid"

# --- Stop Recording Function ---
stop_recording() {
    notify-send "Screen Recording" "Stopping recording..."

    # Read PIDs and temporary file paths from the global PID file
    if [ -f "$GLOBAL_PID_FILE" ]; then
        # Read the PIDs and file paths from the file
        read -r VIDEO_PID AUDIO_PID VIDEO_TEMP_FILE_PATH AUDIO_TEMP_FILE_PATH FINAL_OUTPUT_FILE_PATH < "$GLOBAL_PID_FILE"
        
        # Kill the processes
        kill -INT "$VIDEO_PID" 2>/dev/null # Send interrupt to wf-recorder
        kill -INT "$AUDIO_PID" 2>/dev/null # Send interrupt to pw-record
        
        # Remove the PID file immediately
        rm "$GLOBAL_PID_FILE"
    fi

    # Give processes a moment to stop and write their data
    sleep 1.5 # Increased sleep for better file finalization

    # Check if temp files exist and merge
    if [ -f "$VIDEO_TEMP_FILE_PATH" ] && [ -s "$VIDEO_TEMP_FILE_PATH" ] && \
       [ -f "$AUDIO_TEMP_FILE_PATH" ] && [ -s "$AUDIO_TEMP_FILE_PATH" ]; then
        notify-send "Merging Recording..." "Combining video and audio. This may take a moment."

        # FFmpeg merge command (re-using paths from the PID file)
        ffmpeg -i "$VIDEO_TEMP_FILE_PATH" -i "$AUDIO_TEMP_FILE_PATH" \
               -c:v libx264 -pix_fmt yuv420p \
               -c:a aac -strict -2 \
               -map 0:v:0 -map 1:a:0 -y \
               "$FINAL_OUTPUT_FILE_PATH" -loglevel warning

        if [ $? -eq 0 ]; then # Check if ffmpeg command was successful
            notify-send "Recording Saved!" "Saved to $(basename "$FINAL_OUTPUT_FILE_PATH")"
            rm "$VIDEO_TEMP_FILE_PATH" "$AUDIO_TEMP_FILE_PATH" # Clean up temporary files
        else
            notify-send "Recording Error!" "Failed to merge video and audio. Temp files: $(basename "$VIDEO_TEMP_FILE_PATH"), $(basename "$AUDIO_TEMP_FILE_PATH")."
        fi
    elif [ -f "$VIDEO_TEMP_FILE_PATH" ] && [ -s "$VIDEO_TEMP_FILE_PATH" ]; then
        # If only video exists and is not empty
        # Generate a new final name if audio was missing
        FINAL_VIDEO_ONLY_FILE="$FINAL_RECORD_DIR/video_only_$(date +%Y%m%d_%H%M%S).mp4"
        mv "$VIDEO_TEMP_FILE_PATH" "$FINAL_VIDEO_ONLY_FILE"
        notify-send "Recording Stopped!" "Video saved to $(basename "$FINAL_VIDEO_ONLY_FILE") (no audio recorded or audio failed)."
        [ -f "$AUDIO_TEMP_FILE_PATH" ] && rm "$AUDIO_TEMP_FILE_PATH" # Clean up audio temp if it exists
    else
        notify-send "Recording Stopped!" "No valid video or audio files were found for merging/saving."
        [ -f "$VIDEO_TEMP_FILE_PATH" ] && rm "$VIDEO_TEMP_FILE_PATH"
        [ -f "$AUDIO_TEMP_FILE_PATH" ] && rm "$AUDIO_TEMP_FILE_PATH"
    fi
    exit 0
}

# --- Main Logic ---
# Check if a recording is already running by looking for the GLOBAL_PID_FILE
if [ -f "$GLOBAL_PID_FILE" ]; then
    stop_recording # If file exists, a recording is active, so stop it
else
    # --- Start New Recording ---
    # Define temporary file names using current script's PID and timestamp
    TEMP_SUFFIX="$(date +%Y%m%d_%H%M%S)_$$" # Timestamp + current script PID
    VIDEO_TEMP_FILE="$RECORD_VIDEO_DIR/temp_video_${TEMP_SUFFIX}.mp4"
    AUDIO_TEMP_FILE="$RECORD_AUDIO_DIR/temp_audio_${TEMP_SUFFIX}.flac"
    FINAL_OUTPUT_FILE="$FINAL_RECORD_DIR/recording_${TEMP_SUFFIX}.mp4"

    # Prompt for recording type using Rofi
    CHOICE=$(echo -e "region\nmonitor\ncancel" | rofi -dmenu -p "Record Screen (with Audio):")

    case "$CHOICE" in
        "region")
            notify-send "Recording Started!" "Select region to record with audio. Click and drag or click window."
            # Start wf-recorder for video (in background)
            wf-recorder -g "$(slurp)" -f "$VIDEO_TEMP_FILE" &
            VIDEO_PID=$! # Get PID of wf-recorder

            # Start pw-record for audio (in background)
            pw-record "$AUDIO_SOURCE" "$AUDIO_TEMP_FILE" &
            AUDIO_PID=$! # Get PID of pw-record
            ;;
        "monitor")
            notify-send "Recording Started!" "Recording focused monitor with audio."
            MONITOR_NAME=$(hyprctl monitors | grep "focused: yes" | awk '{print $2}')
            wf-recorder -o "$MONITOR_NAME" -f "$VIDEO_TEMP_FILE" &
            VIDEO_PID=$!

            pw-record "$AUDIO_TEMP_FILE" &
            AUDIO_PID=$!
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

    # If both video and audio processes started successfully, store their PIDs and file paths
    if [ -n "$VIDEO_PID" ] && [ -n "$AUDIO_PID" ]; then
        # Store PIDs AND temp file paths in the GLOBAL_PID_FILE for the stop function to read
        echo "$VIDEO_PID $AUDIO_PID $VIDEO_TEMP_FILE $AUDIO_TEMP_FILE $FINAL_OUTPUT_FILE" > "$GLOBAL_PID_FILE"
        notify-send "Recording..." "Press the hotkey again to stop recording."
    else
        notify-send "Recording Error!" "Failed to start one or both recording processes."
        # Clean up any partial processes or temp files if one failed
        [ -n "$VIDEO_PID" ] && kill -9 "$VIDEO_PID" 2>/dev/null
        [ -n "$AUDIO_PID" ] && kill -9 "$AUDIO_PID" 2>/dev/null
        [ -f "$VIDEO_TEMP_FILE" ] && rm "$VIDEO_TEMP_FILE"
        [ -f "$AUDIO_TEMP_FILE" ] && rm "$AUDIO_TEMP_FILE"
        exit 1
    fi
fi