#!/bin/zsh

SOUND_FILE="$1"
MAX_HEADPHONE_VOL=40  # your threshold %

# Check if headphones are plugged in
SINK=$(pactl get-default-sink)
PORT=$(pactl list sinks | grep "Active Port" | grep -i "head")

if [[ -n "$PORT" ]]; then
    # Headphones detected — cap volume
    CURRENT_VOL=$(pamixer --get-volume)
    
    if [[ "$CURRENT_VOL" -gt "$MAX_HEADPHONE_VOL" ]]; then
        pamixer --set-volume "$MAX_HEADPHONE_VOL"
        paplay "$SOUND_FILE"
        pamixer --set-volume "$CURRENT_VOL"  # restore original
    else
        paplay "$SOUND_FILE"
    fi
else
    # No headphones — play normally
    paplay "$SOUND_FILE"
fi
