#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if an unset variable is used.
# Print commands and their arguments as they are executed (for debugging).
set -eux

# --- Configuration ---
RECORD_VIDEO_DIR="$HOME/Videos/Recordings"
RECORD_AUDIO_DIR="$HOME/.cache/recordings_audio" # Temporary directory for audio
FINAL_RECORD_DIR="$HOME/Videos/Recordings"       # Final destination for merged file

# AUDIO_SOURCE: Recording system audio OUTPUT (monitor of your HDMI)
AUDIO_SOURCE="alsa_output.pci-0000_06_00.1.hdmi-stereo-extra1.monitor"

# --- Video Quality Setting ---
# CRF (Constant Rate Factor) for libx264 encoder.
# Lower values mean higher quality and larger file sizes.
# Typical range is 18-28. 23 is default, 18 is visually lossless.
VIDEO_CRF=18 # Changed from 20 to 18 for higher quality

# --- Ensure Directories Exist ---
mkdir -p "$RECORD_VIDEO_DIR" "$RECORD_AUDIO_DIR" "$FINAL_RECORD_DIR"

# --- Define Global PID File ---
# This file will hold the PIDs and temporary file paths of the currently active recording
# Format: VIDEO_PID AUDIO_PID VIDEO_TEMP_FILE_PATH AUDIO_TEMP_FILE_PATH FINAL_OUTPUT_FILE_PATH
GLOBAL_PID_FILE="/tmp/hypr_recorder_active.pid"

# --- Pre-flight Checks for Tools ---
check_command() {
    if ! command -v "$1" &> /dev/null; then
        notify-send "Recording Error!" "'$1' command not found. Please install it."
        echo "Error: '$1' command not found. Please install it." >&2
        exit 1
    fi
}

check_command "grim"
check_command "slurp"
check_command "swappy"
check_command "wf-recorder"
check_command "parecord"
check_command "ffmpeg"
check_command "notify-send"
# Removed rofi check as it's no longer used
check_command "pactl" # For debugging audio sources

# --- Stop Recording Function ---
stop_recording() {
    notify-send "Screen Recording" "Stopping recording..."

    # Read PIDs and temporary file paths from the global PID file
    if [ -f "$GLOBAL_PID_FILE" ]; then
        # Read the PIDs and file paths from the file
        read -r VIDEO_PID AUDIO_PID VIDEO_TEMP_FILE_PATH AUDIO_TEMP_FILE_PATH FINAL_OUTPUT_FILE_PATH < "$GLOBAL_PID_FILE"
        
        # Kill the processes
        if kill -0 "$VIDEO_PID" 2>/dev/null; then
            kill -INT "$VIDEO_PID" 2>/dev/null || kill -TERM "$VIDEO_PID" 2>/dev/null || kill -KILL "$VIDEO_PID" 2>/dev/null
        fi
        if [ "$AUDIO_PID" -ne 0 ] && kill -0 "$AUDIO_PID" 2>/dev/null; then
            kill -INT "$AUDIO_PID" 2>/dev/null || kill -TERM "$AUDIO_PID" 2>/dev/null || kill -KILL "$AUDIO_PID" 2>/dev/null
        fi
        
        # Remove the PID file immediately
        rm "$GLOBAL_PID_FILE"
    else
        notify-send "Recording Error!" "No active recording found (PID file missing)."
        exit 1
    fi

    # Give processes a moment to stop and write their data
    sleep 3 # Increased sleep for better file finalization

    # Check which temp files exist and are not empty *after* stopping
    VIDEO_OK=0
    AUDIO_OK=0

    [ -f "$VIDEO_TEMP_FILE_PATH" ] && [ -s "$VIDEO_TEMP_FILE_PATH" ] && VIDEO_OK=1
    [ -f "$AUDIO_TEMP_FILE_PATH" ] && [ -s "$AUDIO_TEMP_FILE_PATH" ] && AUDIO_OK=1

    if [ "$VIDEO_OK" -eq 0 ]; then
        notify-send "Recording Stopped!" "No valid video file was recorded. Aborting merge."
        rm -f "$VIDEO_TEMP_FILE_PATH" "$AUDIO_TEMP_FILE_PATH"
        exit 0
    fi

    # Build FFmpeg command based on available audio
    FFMPEG_INPUTS="-i \"$VIDEO_TEMP_FILE_PATH\""
    FFMPEG_MAP_AUDIO=""
    AUDIO_NOTIFY_MSG=""

    if [ "$AUDIO_OK" -eq 1 ]; then
        FFMPEG_INPUTS+=" -i \"$AUDIO_TEMP_FILE_PATH\""
        FFMPEG_MAP_AUDIO="-map 1:a:0" # Audio is the second input
        AUDIO_NOTIFY_MSG="(with system audio output)"
    else
        notify-send "Audio Warning!" "No system audio recorded."
        echo "WARNING: No system audio recorded." >&2
        AUDIO_NOTIFY_MSG="(no audio recorded)"
    fi

    notify-send "Merging Recording..." "Combining video and audio. This may may take a moment. $AUDIO_NOTIFY_MSG"

    # Construct the full ffmpeg command
    # Use VIDEO_CRF variable for quality setting
    eval "ffmpeg $FFMPEG_INPUTS -map 0:v:0 $FFMPEG_MAP_AUDIO -c:v libx264 -pix_fmt yuv420p -crf $VIDEO_CRF -c:a aac -b:a 192k -strict -2 -y \"$FINAL_OUTPUT_FILE_PATH\" -loglevel warning"

    if [ $? -eq 0 ]; then
        notify-send "Recording Saved!" "Saved to $(basename "$FINAL_OUTPUT_FILE_PATH") $AUDIO_NOTIFY_MSG."
        rm -f "$VIDEO_TEMP_FILE_PATH" "$AUDIO_TEMP_FILE_PATH" # Clean up temp files
    else
        notify-send "Recording Error!" "Failed to merge video and audio with FFmpeg."
        notify-send "Temp files remain:" "$(basename "$VIDEO_TEMP_FILE_PATH"), $(basename "$AUDIO_TEMP_FILE_PATH")."
    fi
    exit 0
}

# --- Main Logic ---
# Check if a recording is already running by looking for the GLOBAL_PID_FILE
if [ -f "$GLOBAL_PID_FILE" ]; then
    stop_recording # If file exists, a recording is active, so stop it
else
    # --- Start New Recording ---
    TEMP_SUFFIX="$(date +%Y%m%d_%H%M%S)_$$"
    VIDEO_TEMP_FILE="$RECORD_VIDEO_DIR/temp_video_${TEMP_SUFFIX}.mp4"
    AUDIO_TEMP_FILE="$RECORD_AUDIO_DIR/temp_audio_${TEMP_SUFFIX}.flac"
    FINAL_OUTPUT_FILE="$FINAL_RECORD_DIR/recording_${TEMP_SUFFIX}.mp4"

    # Removed Rofi menu, always assume "region"
    notify-send "Recording Started!" "Select region to record with audio."
    # Pass CRF to wf-recorder
    wf-recorder -g "$(slurp)" -f "$VIDEO_TEMP_FILE" --codec=libx264 --crf "$VIDEO_CRF" &
    VIDEO_PID=$!
    
    sleep 0.5 # Give wf-recorder a moment
    
    echo "DEBUG: Attempting to start parecord for OUTPUT: '$AUDIO_SOURCE' to file: '$AUDIO_TEMP_FILE'"
    set +e # Disable exit on error for parecord
    parecord --device="$AUDIO_SOURCE" "$AUDIO_TEMP_FILE" 2>&1 &
    AUDIO_PID=$!
    set -e

    # Check if audio recorder actually launched (PID is 0 or process doesn't exist)
    AUDIO_RECORDER_ACTIVE=0
    if [ "$AUDIO_PID" -ne 0 ] && kill -0 "$AUDIO_PID" 2>/dev/null; then AUDIO_RECORDER_ACTIVE=1; fi

    if [ "$AUDIO_RECORDER_ACTIVE" -eq 0 ]; then
        notify-send "Audio Error!" "System audio recorder could not be launched. Proceeding without audio."
        echo "ERROR: System audio recorder could not be launched. Proceeding without audio." >&2
        # Don't exit here, allow video to continue
    fi
    
    # Validate VIDEO PID
    if [ -z "$VIDEO_PID" ] || [ "$VIDEO_PID" -le 0 ] || ! kill -0 "$VIDEO_PID" 2>/dev/null; then
        notify-send "Recording Error!" "Failed to start video recorder (wf-recorder). PID: $VIDEO_PID"
        exit 1
    fi
    
    # Store PIDs and temp file paths in the GLOBAL_PID_FILE
    echo "$VIDEO_PID ${AUDIO_PID:-0} $VIDEO_TEMP_FILE $AUDIO_TEMP_FILE $FINAL_OUTPUT_FILE" > "$GLOBAL_PID_FILE"
    notify-send "Recording..." "Press the hotkey again to stop recording."

    echo "--- Debugging Tip for Audio ---"
    echo "If audio still doesn't work, ensure your monitor source is not muted and its volume is up (e.g., pavucontrol)."
    echo "Check if 'pipewire' and 'wireplumber' services are running: 'systemctl --user status pipewire wireplumber'"
fi
