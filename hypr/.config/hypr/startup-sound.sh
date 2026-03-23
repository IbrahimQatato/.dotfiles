#!/bin/bash

FILE=/home/ibra/.config/hypr/HYPR_IS_LAPTOP.env

if [[ -f "$FILE" ]]; then
    # Read the file, remove the '$', and evaluate the result as a command
    eval "$(sed 's/^\$//' "$FILE")"
else
    echo "Error: File not found."
    exit 1
fi

if [[ "$HYPR_IS_LAPTOP" == "True" ]]; then
  paplay ~/.dotfiles/hypr/.config/hypr/gameboy_on.mp3
else
  paplay ~/.dotfiles/hypr/.config/hypr/game_start.ogg
fi
