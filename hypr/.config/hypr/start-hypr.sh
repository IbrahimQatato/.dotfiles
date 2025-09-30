#!/bin/bash
DIR=/home/ibra/.config/hypr/
FILE=HYPR_IS_LAPTOP.env

if hyprctl monitors | grep -q "eDP-1"; then
    echo "$HYPR_IS_LAPTOP=True" > "${DIR}${FILE}"
else
    echo "$HYPR_IS_LAPTOP=False" > "${DIR}${FILE}"

fi

# exec Hyprland
