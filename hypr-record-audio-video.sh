#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# Exit if an unset variable is used.
# Print commands and their arguments as they are executed (for debugging).
set -eux

# --- Configuration ---
RECORD_VIDEO_DIR="$HOME/Videos/Recordings"
RECORD_AUDIO_DIR="$HOME/.cache/recordings_audio" # Temporary directory for audio
FINAL_RECORD_DIR="$HOME/Videos/Recordings"       # Final destination for merged file

# AUDIO_SOURCES:
# To find your sources, run: pactl list sources | grep "Name:"
# MIC_SOURCE: Your microphone input.
MIC_SOURCE="alsa_input.usb-PreSonus_AudioBox_USB_96_000000000000-00.analog-stereo"
# OUTPUT_MONITOR_SOURCE: The monitor of your system's audio output (what you hear).
OUTPUT_MONITOR_SOURCE="alsa_output.pci-0000_06_00.1.hdmi-stereo-extra1.monitor"

# --- Video Quality Setting ---
# CRF (Constant Rate Factor) for libx264 encoder used by FFmpeg during merge.
# Lower values mean higher quality and larger file sizes.
# Typical range is 18-28. 23 is default, 18 is visually lossless.
VIDEO_CRF=18 # This will be used by ffmpeg, not wf-recorder directly.

# --- Ensure Directories Exist ---
mkdir -p "$RECORD_VIDEO_DIR" "$RECORD_AUDIO_DIR" "$FINAL_RECORD_DIR"

# --- Define Global PID File ---
# This file will hold the PIDs and temporary file paths of the currently active recording
# Format: VIDEO_PID MIC_AUDIO_PID OUTPUT_AUDIO_PID VIDEO_TEMP_FILE_PATH MIC_TEMP_FILE_PATH OUTPUT_TEMP_FILE_PATH FINAL_OUTPUT_FILE_PATH
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
check_command "pactl" # For debugging audio sources
check_command "wl-copy" # For copying file path to clipboard

# --- Stop Recording Function ---
stop_recording() {
    notify-send "Screen Recording" "Stopping recording..."

    # Read PIDs and temporary file paths from the global PID file
    if [ -f "$GLOBAL_PID_FILE" ]; then
        # Read the PIDs and file paths from the file
        read -r VIDEO_PID MIC_AUDIO_PID OUTPUT_AUDIO_PID VIDEO_TEMP_FILE_PATH MIC_TEMP_FILE_PATH OUTPUT_TEMP_FILE_PATH FINAL_OUTPUT_FILE_PATH < "$GLOBAL_PID_FILE"
        
        # Kill the processes
        if kill -0 "$VIDEO_PID" 2>/dev/null; then
            kill -INT "$VIDEO_PID" 2>/dev/null || kill -TERM "$VIDEO_PID" 2>/dev/null || kill -KILL "$VIDEO_PID" 2>/dev/null
        fi
        if [ "$MIC_AUDIO_PID" -ne 0 ] && kill -0 "$MIC_AUDIO_PID" 2>/dev/null; then # Only kill if PID is valid and process exists
            kill -INT "$MIC_AUDIO_PID" 2>/dev/null || kill -TERM "$MIC_AUDIO_PID" 2>/dev/null || kill -KILL "$MIC_AUDIO_PID" 2>/dev/null
        fi
        if [ "$OUTPUT_AUDIO_PID" -ne 0 ] && kill -0 "$OUTPUT_AUDIO_PID" 2>/dev/null; then # Only kill if PID is valid and process exists
            kill -INT "$OUTPUT_AUDIO_PID" 2>/dev/null || kill -TERM "$OUTPUT_AUDIO_PID" 2>/dev/null || kill -KILL "$OUTPUT_AUDIO_PID" 2>/dev/null
        fi
        
        # Remove the PID file immediately
        rm "$GLOBAL_PID_FILE"
    else
        notify-send "Recording Error!" "No active recording found (PID file missing)."
        exit 1
    fi

    # Give processes a moment to stop and write their data
    sleep 5 

    # Check which temp files exist and are not empty *after* stopping
    VIDEO_OK=0
    MIC_AUDIO_OK=0
    OUTPUT_AUDIO_OK=0

    [ -f "$VIDEO_TEMP_FILE_PATH" ] && [ -s "$VIDEO_TEMP_FILE_PATH" ] && VIDEO_OK=1
    [ -f "$MIC_TEMP_FILE_PATH" ] && [ -s "$MIC_TEMP_FILE_PATH" ] && MIC_AUDIO_OK=1
    [ -f "$OUTPUT_TEMP_FILE_PATH" ] && [ -s "$OUTPUT_TEMP_FILE_PATH" ] && OUTPUT_AUDIO_OK=1

    if [ "$VIDEO_OK" -eq 0 ]; then
        notify-send "Recording Stopped!" "No valid video file was recorded. Aborting merge."
        rm -f "$VIDEO_TEMP_FILE_PATH" "$MIC_TEMP_FILE_PATH" "$OUTPUT_TEMP_FILE_PATH"
        exit 0
    fi

    # Construct the full ffmpeg command using an array for robustness
    ffmpeg_cmd=(
        ffmpeg
        -i "$VIDEO_TEMP_FILE_PATH"
    )
    
    AUDIO_INPUT_COUNT=0

    if [ "$MIC_AUDIO_OK" -eq 1 ]; then
        ffmpeg_cmd+=( -i "$MIC_TEMP_FILE_PATH" )
        AUDIO_INPUT_COUNT=$((AUDIO_INPUT_COUNT + 1))
    else
        notify-send "Mic Audio Warning!" "Microphone audio file empty or not found. No mic audio will be included."
        echo "WARNING: Microphone audio file empty or not found. No mic audio will be included." >&2
    fi
    if [ "$OUTPUT_AUDIO_OK" -eq 1 ]; then
        ffmpeg_cmd+=( -i "$OUTPUT_TEMP_FILE_PATH" )
        AUDIO_INPUT_COUNT=$((AUDIO_INPUT_COUNT + 1))
    else
        notify-send "Output Audio Warning!" "System output audio file empty or not found. No system audio will be included."
        echo "WARNING: System output audio file empty or not found. No system audio will be included." >&2
    fi

    AUDIO_NOTIFY_MSG=""
    if [ "$AUDIO_INPUT_COUNT" -eq 2 ]; then
        # Both mic and output audio are present
        # FFmpeg inputs will be: 0=video, 1=mic_audio, 2=output_audio
        ffmpeg_cmd+=( -filter_complex "[1:a][2:a]amix=inputs=2:duration=longest[aout]" )
        ffmpeg_cmd+=( -map "[aout]" )
        AUDIO_NOTIFY_MSG="(with mic and system audio)"
    elif [ "$AUDIO_INPUT_COUNT" -eq 1 ]; then
        # Only one audio source is present (either mic or output)
        # FFmpeg inputs will be: 0=video, 1=single_audio
        ffmpeg_cmd+=( -map 1:a:0 ) # Audio is the second input (index 1 in ffmpeg_cmd)
        if [ "$MIC_AUDIO_OK" -eq 1 ]; then
            AUDIO_NOTIFY_MSG="(with microphone audio only)"
        else # Must be OUTPUT_AUDIO_OK
            AUDIO_NOTIFY_MSG="(with system audio output only)"
        fi
    else
        # No audio sources are present
        AUDIO_NOTIFY_MSG="(no audio recorded)"
        # No audio mapping needed
    fi

    notify-send "Merging Recording..." "Combining video and audio. This may may take a moment. $AUDIO_NOTIFY_MSG"

    # Add common video/audio encoding options
    ffmpeg_cmd+=(
        -map 0:v:0 # Map the first video stream (from the first input, which is video)
        -c:v libx264
        -pix_fmt yuv420p
        -crf "$VIDEO_CRF"
        -c:a aac
        -b:a 192k
        -strict -2
        -y "$FINAL_OUTPUT_FILE_PATH"
        -loglevel warning
    )

    # Execute the ffmpeg command
    "${ffmpeg_cmd[@]}"

    if [ $? -eq 0 ]; then
        notify-send "Recording Saved!" "Saved to $(basename "$FINAL_OUTPUT_FILE_PATH") $AUDIO_NOTIFY_MSG."
        # Copy the final file path to clipboard
        wl-copy "$FINAL_OUTPUT_FILE_PATH"
        notify-send "Clipboard Updated!" "Recording path copied to clipboard."
        rm -f "$VIDEO_TEMP_FILE_PATH" "$MIC_TEMP_FILE_PATH" "$OUTPUT_TEMP_FILE_PATH" # Clean up temp files
    else
        notify-send "Recording Error!" "Failed to merge video and audio with FFmpeg."
        notify-send "Temp files remain:" "$(basename "$VIDEO_TEMP_FILE_PATH"), $(basename "$MIC_TEMP_FILE_PATH"), $(basename "$OUTPUT_TEMP_FILE_PATH")."
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
    MIC_TEMP_FILE="$RECORD_AUDIO_DIR/temp_mic_audio_${TEMP_SUFFIX}.flac"
    OUTPUT_TEMP_FILE="$RECORD_AUDIO_DIR/temp_output_audio_${TEMP_SUFFIX}.flac"
    FINAL_OUTPUT_FILE="$FINAL_RECORD_DIR/recording_${TEMP_SUFFIX}.mp4"

    notify-send "Screen Recorder" "Please select a region to record."
    
    # Get the screen geometry from slurp first. This is the blocking part.
    GEOMETRY=$(slurp)

    # Check if slurp was cancelled (e.g., by pressing Esc).
    if [ -z "$GEOMETRY" ]; then
        notify-send "Recording Cancelled" "No region selected."
        exit 0
    fi

    notify-send "Recording Started!" "Starting video and audio capture for the selected region."

    # Start Video Recorder
    wf-recorder -g "$GEOMETRY" -f "$VIDEO_TEMP_FILE" --codec=libx264 &
    VIDEO_PID=$!
    
    # Start Audio Recorders
    # Disable exit-on-error temporarily in case one of the audio devices is not available
    set +e
    echo "DEBUG: Attempting to start parecord for MIC: '$MIC_SOURCE' to file: '$MIC_TEMP_FILE'"
    parecord --device="$MIC_SOURCE" "$MIC_TEMP_FILE" &
    MIC_AUDIO_PID=$! # Get PID of mic parecord
    
    echo "DEBUG: Attempting to start parecord for OUTPUT: '$OUTPUT_MONITOR_SOURCE' to file: '$OUTPUT_TEMP_FILE'"
    parecord --device="$OUTPUT_MONITOR_SOURCE" "$OUTPUT_TEMP_FILE" &
    OUTPUT_AUDIO_PID=$! # Get PID of output parecord
    set -e # Re-enable exit on error
    
    # Give recorders a moment to initialize before checking their status
    sleep 0.5

    # Check if audio recorders actually launched (PID is 0 or process doesn't exist)
    MIC_RECORDER_ACTIVE=0
    if [ "$MIC_AUDIO_PID" -ne 0 ] && kill -0 "$MIC_AUDIO_PID" 2>/dev/null; then MIC_RECORDER_ACTIVE=1; fi
    OUTPUT_RECORDER_ACTIVE=0
    if [ "$OUTPUT_AUDIO_PID" -ne 0 ] && kill -0 "$OUTPUT_AUDIO_PID" 2>/dev/null; then OUTPUT_RECORDER_ACTIVE=1; fi

    if [ "$MIC_RECORDER_ACTIVE" -eq 0 ] && [ "$OUTPUT_RECORDER_ACTIVE" -eq 0 ]; then
        notify-send "Audio Error!" "Neither microphone nor system output recorder could be launched. Aborting."
        echo "ERROR: Neither audio recording stream could be launched. Aborting." >&2
        kill -TERM "$VIDEO_PID" 2>/dev/null # Stop video if no audio at all
        exit 1
    fi
    
    # Validate VIDEO PID
    if [ -z "$VIDEO_PID" ] || [ "$VIDEO_PID" -le 0 ] || ! kill -0 "$VIDEO_PID" 2>/dev/null; then
        notify-send "Recording Error!" "Failed to start video recorder (wf-recorder). PID: $VIDEO_PID"
        # Also kill any audio recorders that might have started
        [ "$MIC_RECORDER_ACTIVE" -eq 1 ] && kill -TERM "$MIC_AUDIO_PID"
        [ "$OUTPUT_RECORDER_ACTIVE" -eq 1 ] && kill -TERM "$OUTPUT_AUDIO_PID"
        exit 1
    fi
    
    # Store PIDs and temp file paths in the GLOBAL_PID_FILE
    echo "$VIDEO_PID ${MIC_AUDIO_PID:-0} ${OUTPUT_AUDIO_PID:-0} $VIDEO_TEMP_FILE $MIC_TEMP_FILE $OUTPUT_TEMP_FILE $FINAL_OUTPUT_FILE" > "$GLOBAL_PID_FILE"
    notify-send "Recording..." "Press the hotkey again to stop recording."

    echo "--- Debugging Tip for Audio ---"
    echo "If audio still doesn't work, ensure your microphone and monitor sources are not muted and their volumes are up (e.g., pavucontrol)."
    echo "Check if 'pipewire' and 'wireplumber' services are running: 'systemctl --user status pipewire wireplumber'"
fi
